# Profiles the /api/v2/addresses/:hash/internal-transactions pipeline stage by
# stage from an IEx console, replaying exactly what the endpoint does (DB
# queries and, when triggered, the on-demand JSON-RPC fetch included), plus an
# optional per-SQL-query breakdown built on Ecto telemetry.
#
# Usage on an API pod:
#
#   kubectl cp scripts/address_itx_profiler.exs <pod>:/tmp/address_itx_profiler.exs
#   kubectl exec -it <pod> -- bin/blockscout remote
#   iex> Code.eval_file("/tmp/address_itx_profiler.exs")
#   iex> AddressItxProfiler.profile("0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045")
#   iex> AddressItxProfiler.queries("0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045")
#
# (Pasting the whole module into IEx works too.)
#
# When the on-demand fetch is triggered, the profile additionally lists every
# trace RPC batch request (EthereumJSONRPC.fetch_internal_transactions /
# fetch_block_internal_transactions call) with its duration, chunk contents,
# and result status, captured via :erlang.trace scoped to the profiler process.
#
# All work is read-only, but note that when the DB has too few rows the
# profiler — like the endpoint itself — performs the on-demand internal
# transactions fetch against the archive node.
defmodule AddressItxProfiler do
  @moduledoc """
  Stage-by-stage profiler for the `/api/v2/addresses/:hash/internal-transactions`
  pipeline.

  - `profile/2` — one address, timings per pipeline stage; when the on-demand
    fetch is triggered, also per-batch timings of the trace RPC requests
  - `queries/3` — one address, per-SQL-query time breakdown
    (`queue` vs `query` vs `decode`) collected via Ecto telemetry
  """

  alias BlockScoutWeb.API.V2.TransactionView
  alias Explorer.Chain
  alias Explorer.Chain.Address.MetadataPreloader
  alias Explorer.Chain.Address.Reputation
  alias Explorer.Chain.InternalTransaction
  alias Explorer.Chain.SmartContract.Proxy.Models.Implementation
  alias Explorer.PagingOptions
  alias Indexer.Fetcher.OnDemand.InternalTransaction, as: InternalTransactionOnDemand

  @api_true [api?: true]

  @telemetry_events [
    [:explorer, :repo, :query],
    [:explorer, :repo, :replica1, :query],
    [:explorer, :repo, :account, :query]
  ]

  @sub_stage_prefix "  "

  # Both on-demand variants funnel their trace requests through these two
  # functions; one call = one batched JSON-RPC request (one chunk).
  @traced_rpc_functions [
    {EthereumJSONRPC, :fetch_internal_transactions, 2},
    {EthereumJSONRPC, :fetch_block_internal_transactions, 2}
  ]

  @doc """
  Profiles a single address through every stage of the endpoint.

  Options:
  - `print?: false` returns the timings map silently
  - `paging_options: %Explorer.PagingOptions{...}` to profile a later page
    (defaults to the endpoint's first-page paging)
  """
  def profile(address_string, opts \\ []) do
    print? = Keyword.get(opts, :print?, true)
    paging = Keyword.get(opts, :paging_options, PagingOptions.default_paging_options())
    fetch_options = [paging_options: paging] ++ internal_transactions_options()

    case Chain.string_to_address_hash(address_string) do
      {:ok, address_hash} ->
        {_address_result, t_address} = timed(fn -> Chain.hash_to_address(address_hash, address_options()) end)

        # what the endpoint actually calls: DB fetch + optional on-demand RPC + merge
        {internal_transactions, t_total_fetch} =
          timed(fn -> BlockScoutWeb.Chain.address_to_internal_transactions(address_hash, fetch_options) end)

        # sub-stages, re-measured separately
        {from_db, t_db_fetch} =
          timed(fn -> InternalTransaction.fetch_from_db_by_address(address_hash, fetch_options) end)

        {_repreloaded, t_addr_preloads} =
          timed(fn -> InternalTransaction.preload_addresses(from_db, fetch_options) end)

        should_fetch_on_demand? = InternalTransactionOnDemand.should_fetch?(from_db, paging.page_size)

        {{_on_demand, t_on_demand}, trace_batches} =
          if should_fetch_on_demand? do
            capture_trace_batches(fn ->
              timed(fn -> InternalTransactionOnDemand.fetch_by_address(address_hash, fetch_options) end)
            end)
          else
            {{[], nil}, []}
          end

        {with_meta, t_ens} =
          timed(fn -> MetadataPreloader.maybe_preload_ens_and_metadata(internal_transactions) end)

        {rendered, t_render} =
          timed(fn ->
            TransactionView.render("internal_transactions.json", %{
              internal_transactions: with_meta,
              next_page_params: nil
            })
          end)

        {_json, t_encode} = timed(fn -> Jason.encode!(rendered) end)

        stages =
          [
            {"hash_to_address", t_address},
            {"address_to_internal_transactions", t_total_fetch},
            {@sub_stage_prefix <> "DB fetch (incl. addr preloads)", t_db_fetch},
            {@sub_stage_prefix <> "address preloads (re-run)", t_addr_preloads},
            {@sub_stage_prefix <> "on-demand RPC fetch", t_on_demand},
            {"ENS + metadata preload", t_ens},
            {"render internal_transactions.json", t_render},
            {"json encode", t_encode}
          ]
          |> Enum.reject(fn {_label, ms} -> is_nil(ms) end)

        if print? do
          print_stages(address_string, stages)

          IO.puts(
            "items: #{length(internal_transactions)}, on-demand RPC: " <>
              ((should_fetch_on_demand? && "TRIGGERED") || "skipped (DB sufficient)")
          )

          print_trace_batches(trace_batches, t_on_demand)
        end

        {:ok, stages |> Map.new() |> Map.put(:trace_batches, trace_batches)}

      :error ->
        if print?, do: IO.puts("invalid address hash: #{address_string}")
        :invalid_hash
    end
  end

  @doc """
  Profiles one address while recording every SQL query via Ecto telemetry, then
  prints totals (queue vs query vs decode time), per-repo sums, and the `top`
  slowest query shapes.

  By default only queries belonging to the profiled request are recorded
  (matched via the `$callers` process ancestry, which covers Ecto's parallel
  preload tasks). Pass `scope: :node` to record every query on the node during
  the run instead.
  """
  def queries(address_string, top \\ 15, opts \\ []) do
    table = :ets.new(:address_itx_profiler_queries, [:public, :duplicate_bag])
    handler_id = "address-itx-profiler-#{System.unique_integer([:positive])}"
    root = if Keyword.get(opts, :scope, :request) == :node, do: :node, else: self()

    :telemetry.attach_many(handler_id, @telemetry_events, &__MODULE__.handle_query_event/4, {table, root})

    try do
      profile(address_string, print?: false)
    after
      :telemetry.detach(handler_id)
    end

    entries = :ets.tab2list(table)
    :ets.delete(table)

    print_query_report(entries, top)
  end

  @doc false
  def handle_query_event(_event, measurements, metadata, {table, root}) do
    if root == :node or self() == root or root in Process.get(:"$callers", []) do
      :ets.insert(table, {measurements, metadata.repo, metadata.source, metadata.query})
    end
  end

  # --- endpoint pipeline reconstruction -------------------------------------

  # Mirrors @address_options in BlockScoutWeb.API.V2.AddressController.
  # Chain-type compile-time extras are not replicated.
  defp address_options do
    [
      necessity_by_association: %{
        :names => :optional,
        :scam_badge => :optional,
        :signed_authorization => :optional,
        :smart_contract => :optional,
        [token: Reputation.reputation_association()] => :optional
      },
      api?: true
    ]
  end

  # Mirrors the full_options built in the internal_transactions action
  # (no direction filter, i.e. the plain endpoint call without ?filter=).
  defp internal_transactions_options do
    [
      address_preloads: [
        created_contract_address: [
          :scam_badge,
          :names,
          :smart_contract,
          Implementation.proxy_implementations_association()
        ],
        from_address: [:scam_badge, :names, :smart_contract, Implementation.proxy_implementations_association()],
        to_address: [:scam_badge, :names, :smart_contract, Implementation.proxy_implementations_association()]
      ]
    ] ++ @api_true
  end

  # --- trace RPC batch capture -----------------------------------------------

  # Runs `fun` with :erlang call tracing enabled on @traced_rpc_functions for
  # the current process (and processes it spawns), returning {result, batches}
  # where each batch is %{function, summary, ms, status}. Public for smoke
  # testing; not part of the profiling API.
  @doc false
  def capture_trace_batches(fun) do
    parent = self()
    collector = spawn(fn -> collect_trace_events([], parent) end)

    tracing? =
      try do
        Enum.each(@traced_rpc_functions, fn {m, f, a} ->
          Code.ensure_loaded(m)
          :erlang.trace_pattern({m, f, a}, [{:_, [], [{:return_trace}, {:exception_trace}]}], [:global])
        end)

        :erlang.trace(self(), true, [:call, :timestamp, :set_on_spawn, {:tracer, collector}])
        true
      rescue
        _ -> false
      end

    result =
      try do
        fun.()
      after
        if tracing? do
          :erlang.trace(self(), false, [:call, :timestamp, :set_on_spawn])
          Enum.each(@traced_rpc_functions, fn mfa -> :erlang.trace_pattern(mfa, false, [:global]) end)
        end
      end

    send(collector, :stop)

    batches =
      receive do
        {:trace_events, events} -> pair_trace_events(events)
      after
        1_000 -> []
      end

    {result, batches}
  end

  defp collect_trace_events(events, parent) do
    receive do
      :stop ->
        send(parent, {:trace_events, Enum.reverse(events)})

      event when elem(event, 0) == :trace_ts ->
        collect_trace_events([event | events], parent)

      _other ->
        collect_trace_events(events, parent)
    after
      # self-destruct if the profiling process died without sending :stop
      600_000 -> :ok
    end
  end

  defp pair_trace_events(events) do
    {batches, _pending} =
      Enum.reduce(events, {[], %{}}, fn
        {:trace_ts, pid, :call, {_m, f, args}, ts}, {done, pending} ->
          {done, Map.put(pending, pid, {f, summarize_rpc_args(f, args), ts})}

        {:trace_ts, pid, :return_from, {_m, f, _a}, return, ts}, {done, pending} ->
          finish_trace_event(pid, f, rpc_status(return), ts, done, pending)

        {:trace_ts, pid, :exception_from, {_m, f, _a}, {class, _reason}, ts}, {done, pending} ->
          finish_trace_event(pid, f, to_string(class), ts, done, pending)

        _event, acc ->
          acc
      end)

    Enum.reverse(batches)
  end

  defp finish_trace_event(pid, function, status, ts, done, pending) do
    case Map.pop(pending, pid) do
      {{^function, summary, start_ts}, rest} ->
        batch = %{function: function, summary: summary, ms: :timer.now_diff(ts, start_ts) / 1000, status: status}
        {[batch | done], rest}

      {_other, rest} ->
        {done, rest}
    end
  end

  defp summarize_rpc_args(:fetch_internal_transactions, [transactions, _named_args]) when is_list(transactions) do
    blocks = transactions |> Enum.map(& &1[:block_number]) |> Enum.reject(&is_nil/1) |> Enum.uniq()
    "#{length(transactions)} txs in #{block_range(blocks)}"
  end

  defp summarize_rpc_args(:fetch_block_internal_transactions, [block_numbers, _named_args])
       when is_list(block_numbers) do
    block_range(block_numbers)
  end

  defp summarize_rpc_args(_function, _args), do: "?"

  defp block_range([]), do: "no blocks"
  defp block_range([block]), do: "block #{block}"
  defp block_range(blocks), do: "#{length(blocks)} blocks #{Enum.min(blocks)}..#{Enum.max(blocks)}"

  defp rpc_status({:ok, _}), do: "ok"
  defp rpc_status({:error, _}), do: "error"
  defp rpc_status(:ignore), do: "ignore"
  defp rpc_status(_), do: "other"

  defp print_trace_batches([], _stage_ms), do: :ok

  defp print_trace_batches(batches, stage_ms) do
    rpc_total = batches |> Enum.map(& &1.ms) |> Enum.sum()

    IO.puts(
      "\non-demand trace batches: #{length(batches)}, RPC total #{format_ms(rpc_total)} ms" <>
        if(stage_ms, do: " of #{format_ms(stage_ms)} ms stage (rest = DB work in the fetcher)", else: "")
    )

    batches
    |> Enum.with_index(1)
    |> Enum.each(fn {batch, index} ->
      IO.puts(
        "  ##{String.pad_trailing(to_string(index), 4)}" <>
          "#{String.pad_leading(format_ms(batch.ms), 10)} ms  " <>
          "#{String.pad_trailing(batch.status, 7)}#{batch.summary}  (#{batch.function})"
      )
    end)

    :ok
  end

  # --- timing / reporting ----------------------------------------------------

  defp timed(fun) do
    start = System.monotonic_time(:microsecond)
    result = fun.()
    {result, (System.monotonic_time(:microsecond) - start) / 1000}
  end

  defp print_stages(address_string, stages) do
    IO.puts("\n=== #{address_string} internal-transactions ===")
    Enum.each(stages, fn {label, ms} -> print_line(label, format_ms(ms)) end)
    IO.puts(String.duplicate("-", 60))
    print_line("TOTAL", format_ms(total_ms(Map.new(stages))))
    :ok
  end

  defp total_ms(stages_map) do
    stages_map
    |> Enum.reject(fn {label, _} -> String.starts_with?(label, @sub_stage_prefix) end)
    |> Enum.map(&elem(&1, 1))
    |> Enum.sum()
  end

  defp print_query_report([], _top) do
    IO.puts("no queries recorded")
  end

  defp print_query_report(entries, top) do
    rows =
      Enum.map(entries, fn {m, repo, source, query} ->
        %{
          repo: repo,
          source: source,
          query: query,
          total: to_ms(m[:total_time]),
          queue: to_ms(m[:queue_time]),
          query_time: to_ms(m[:query_time]),
          decode: to_ms(m[:decode_time])
        }
      end)

    total = rows |> Enum.map(& &1.total) |> Enum.sum()
    queue = rows |> Enum.map(& &1.queue) |> Enum.sum()
    query_time = rows |> Enum.map(& &1.query_time) |> Enum.sum()
    decode = rows |> Enum.map(& &1.decode) |> Enum.sum()

    IO.puts("\n=== #{length(rows)} queries, total #{format_ms(total)} ms ===")
    IO.puts("queue: #{format_ms(queue)} ms | query: #{format_ms(query_time)} ms | decode: #{format_ms(decode)} ms")
    IO.puts("(large queue share -> DB pool contention, not slow SQL)\n")

    rows
    |> Enum.group_by(& &1.repo)
    |> Enum.each(fn {repo, repo_rows} ->
      IO.puts(
        "#{inspect(repo)}: #{length(repo_rows)} queries, #{format_ms(Enum.sum(Enum.map(repo_rows, & &1.total)))} ms"
      )
    end)

    IO.puts("\ntop #{top} query shapes by total time:")

    rows
    |> Enum.group_by(& &1.query)
    |> Enum.map(fn {query, group} ->
      {query, length(group), Enum.sum(Enum.map(group, & &1.total)), Enum.max(Enum.map(group, & &1.total)),
       Enum.sum(Enum.map(group, & &1.queue)), List.first(group).source}
    end)
    |> Enum.sort_by(fn {_q, _c, total, _max, _queue, _s} -> -total end)
    |> Enum.take(top)
    |> Enum.each(fn {query, count, total, max, queue, source} ->
      IO.puts(
        "#{String.pad_leading(format_ms(total), 8)} ms " <>
          "(n=#{String.pad_trailing(to_string(count), 3)} max=#{format_ms(max)} queue=#{format_ms(queue)}) " <>
          "#{source || "-"} | #{truncate(query, 120)}"
      )
    end)

    :ok
  end

  defp to_ms(nil), do: 0.0
  defp to_ms(native), do: System.convert_time_unit(native, :native, :microsecond) / 1000

  defp format_ms(ms), do: :erlang.float_to_binary(ms / 1, decimals: 1)

  defp print_line(label, value), do: IO.puts(String.pad_trailing(label, 38) <> value)

  defp truncate(string, max) do
    string = String.replace(string, ~r/\s+/, " ")
    if String.length(string) > max, do: String.slice(string, 0, max) <> "...", else: string
  end
end
