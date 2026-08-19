# Profiles the /api/v2/tokens/:hash/holders pipeline stage by stage from an
# IEx console, replaying exactly what the endpoint does (queries included),
# plus an optional per-SQL-query breakdown built on Ecto telemetry.
#
# Usage on an API pod:
#
#   kubectl cp scripts/token_holders_profiler.exs <pod>:/tmp/token_holders_profiler.exs
#   kubectl exec -it <pod> -- bin/blockscout remote
#   iex> Code.eval_file("/tmp/token_holders_profiler.exs")
#   iex> TokenHoldersProfiler.profile("0x54FA517F05e11Ffa87f4b22AE87d91Cec0C2D7E1")
#   iex> TokenHoldersProfiler.queries("0x54FA517F05e11Ffa87f4b22AE87d91Cec0C2D7E1")
#
# (Pasting the whole module into IEx works too.)
#
# All work is read-only.
defmodule TokenHoldersProfiler do
  @moduledoc """
  Stage-by-stage profiler for the `/api/v2/tokens/:hash/holders` pipeline.

  - `profile/2` — one token, timings per pipeline stage
  - `queries/3` — one token, per-SQL-query time breakdown
    (`queue` vs `query` vs `decode`) collected via Ecto telemetry
  """

  alias BlockScoutWeb.API.V2.TokenView
  alias Explorer.Chain
  alias Explorer.Chain.Address.CurrentTokenBalance
  alias Explorer.Chain.Address.MetadataPreloader
  alias Explorer.Chain.Token
  alias Explorer.PagingOptions

  @api_true [api?: true]

  @telemetry_events [
    [:explorer, :repo, :query],
    [:explorer, :repo, :replica1, :query],
    [:explorer, :repo, :account, :query]
  ]

  @sub_stage_prefix "  "

  @doc """
  Profiles a single token contract address through every stage of the endpoint.

  Options:
  - `print?: false` returns the timings map silently
  - `paging_options: %Explorer.PagingOptions{...}` to profile a later page
    (the holders paging key is `{value, address_hash_bytes}` from a previous
    page's `next_page_params`); defaults to the endpoint's first-page paging
  """
  def profile(address_string, opts \\ []) do
    print? = Keyword.get(opts, :print?, true)
    paging = Keyword.get(opts, :paging_options, PagingOptions.default_paging_options())
    fetch_options = [paging_options: paging] ++ @api_true

    case Chain.string_to_address_hash(address_string) do
      {:ok, address_hash} ->
        {exists?, t_exists} = timed(fn -> Token.by_contract_address_hash_exists?(address_hash, @api_true) end)

        if exists? do
          # what the endpoint actually calls: holders query + address preload wave
          {results_plus_one, t_holders} =
            timed(fn -> Chain.fetch_token_holders_from_token_hash(address_hash, fetch_options) end)

          # sub-stage: the same query without the address preloads
          {_bare, t_holders_bare} =
            timed(fn ->
              case CurrentTokenBalance.token_holders_ordered_by_value_query_without_address_preload(
                     address_hash,
                     fetch_options
                   ) do
                # `%PagingOptions{key: {0, _}}` short-circuits to a plain list
                list when is_list(list) -> list
                query -> Chain.select_repo(fetch_options).all(query)
              end
            end)

          {token_balances, _next_page} = BlockScoutWeb.Chain.split_list_by_page(results_plus_one)

          {with_meta, t_ens} = timed(fn -> MetadataPreloader.maybe_preload_ens_and_metadata(token_balances) end)

          {rendered, t_render} =
            timed(fn ->
              TokenView.render("token_holders.json", %{token_balances: with_meta, next_page_params: nil})
            end)

          {_json, t_encode} = timed(fn -> Jason.encode!(rendered) end)

          stages = [
            {"token exists check", t_exists},
            {"fetch_token_holders", t_holders},
            {@sub_stage_prefix <> "holders query (no addr preload)", t_holders_bare},
            {"ENS + metadata preload", t_ens},
            {"render token_holders.json", t_render},
            {"json encode", t_encode}
          ]

          if print? do
            print_stages(address_string, stages)
            IO.puts("holders on page: #{length(token_balances)}")
          end

          {:ok, Map.new(stages)}
        else
          if print?, do: IO.puts("token #{address_string} not found (exists check took #{format_ms(t_exists)} ms)")
          :not_found
        end

      :error ->
        if print?, do: IO.puts("invalid token contract address hash: #{address_string}")
        :invalid_hash
    end
  end

  @doc """
  Profiles one token while recording every SQL query via Ecto telemetry, then
  prints totals (queue vs query vs decode time), per-repo sums, and the `top`
  slowest query shapes.

  By default only queries belonging to the profiled request are recorded
  (matched via the `$callers` process ancestry, which covers Ecto's parallel
  preload tasks). Pass `scope: :node` to record every query on the node during
  the run instead.
  """
  def queries(address_string, top \\ 15, opts \\ []) do
    table = :ets.new(:token_holders_profiler_queries, [:public, :duplicate_bag])
    handler_id = "token-holders-profiler-#{System.unique_integer([:positive])}"
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

  # --- timing / reporting ----------------------------------------------------

  defp timed(fun) do
    start = System.monotonic_time(:microsecond)
    result = fun.()
    {result, (System.monotonic_time(:microsecond) - start) / 1000}
  end

  defp print_stages(address_string, stages) do
    IO.puts("\n=== #{address_string} holders ===")
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
