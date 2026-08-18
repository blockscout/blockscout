# Profiles the /api/v2/transactions/:hash pipeline stage by stage from an IEx
# console, replaying exactly what the endpoint does (queries included), plus an
# optional per-SQL-query breakdown built on Ecto telemetry.
#
# Usage on an API pod:
#
#   kubectl cp scripts/tx_profiler.exs <pod>:/tmp/tx_profiler.exs
#   kubectl exec -it <pod> -- bin/blockscout remote
#   iex> Code.eval_file("/tmp/tx_profiler.exs")
#   iex> TxProfiler.profile("0x4df018df6bd014bc9d23796f837051ea639cc6a7138782e9192e4f55f1dd747c")
#   iex> TxProfiler.queries("0x4df018df6bd014bc9d23796f837051ea639cc6a7138782e9192e4f55f1dd747c")
#   iex> TxProfiler.run(20)
#   iex> TxProfiler.microservices()  # DNS / TCP / TLS / TTFB per microservice endpoint
#
# (Pasting the whole module into IEx works too.)
#
# Run `profile/1` twice to compare cold vs warm caches (BlockNumber, contract
# methods, sig-provider). All work is read-only.
defmodule TxProfiler do
  @moduledoc """
  Stage-by-stage profiler for the `/api/v2/transactions/:hash` pipeline.

  - `profile/2` — one transaction, timings per pipeline stage
  - `run/1` — N most recent transactions, avg/max per stage
  - `queries/2` — one transaction, per-SQL-query time breakdown
    (`queue` vs `query` vs `decode`) collected via Ecto telemetry
  """

  import Ecto.Query, only: [from: 2]

  alias BlockScoutWeb.API.V2.TransactionView
  alias BlockScoutWeb.Models.GetAddressTags
  alias Explorer.Chain
  alias Explorer.Chain.Address.MetadataPreloader
  alias Explorer.Chain.Address.Reputation
  alias Explorer.Chain.Cache.BlockNumber
  alias Explorer.Chain.SmartContract
  alias Explorer.Chain.SmartContract.Proxy.Models.Implementation
  alias Explorer.Chain.Token.Instance
  alias Explorer.Chain.Transaction

  @api_true [api?: true]

  @telemetry_events [
    [:explorer, :repo, :query],
    [:explorer, :repo, :replica1, :query],
    [:explorer, :repo, :account, :query]
  ]

  @sub_stage_prefix "  "

  @doc """
  Profiles a single transaction hash through every stage of the endpoint.

  Options: `print?: false` returns the timings map silently (used by `run/1`).
  """
  def profile(hash_string, opts \\ []) do
    print? = Keyword.get(opts, :print?, true)

    with {:ok, hash} <- Chain.string_to_full_hash(hash_string),
         {{:ok, transaction}, t_fetch} <-
           timed(fn ->
             Chain.hash_to_transaction(hash, [necessity_by_association: transaction_necessity()] ++ @api_true)
           end) do
      {preloaded, t_transfers} =
        timed(fn -> Chain.preload_token_transfers(transaction, token_transfers_necessity(), @api_true) end)

      {preloaded, t_participants} =
        if unified_participants_preload?() do
          timed(fn ->
            Chain.preload_transaction_participants(preloaded, participants_necessity(), @api_true)
          end)
        else
          {preloaded, nil}
        end

      {with_nft, t_nft} = timed(fn -> Instance.preload_nft(preloaded, @api_true) end)
      {final_tx, t_ens} = timed(fn -> MetadataPreloader.maybe_preload_ens_and_metadata(with_nft) end)

      # per-service split of the ENS + metadata stage (re-runs each HTTP call
      # separately; the combined stage above runs them concurrently)
      ens_sub_stages =
        if function_exported?(MetadataPreloader, :maybe_preload_selected_meta, 2) do
          {_r, t_ens_only} =
            timed(fn -> MetadataPreloader.maybe_preload_selected_meta(with_nft, [:ens_domain_name]) end)

          {_r, t_meta_only} = timed(fn -> MetadataPreloader.maybe_preload_selected_meta(with_nft, [:metadata]) end)

          [
            {@sub_stage_prefix <> "ENS lookup (BENS)", t_ens_only},
            {@sub_stage_prefix <> "metadata lookup", t_meta_only}
          ]
        else
          []
        end

      # sub-stages of render, measured separately (render repeats them internally)
      {_height, t_height} = timed(fn -> BlockNumber.get_max() end)
      {_decoded, t_decode} = timed(fn -> Transaction.decode_transactions([final_tx], false, @api_true) end)
      {_tags, t_tags} = timed(fn -> GetAddressTags.get_address_tags_batch(address_hashes(final_tx), nil, @api_true) end)

      {rendered, t_render} =
        timed(fn -> TransactionView.render("transaction.json", %{transaction: final_tx, conn: %Plug.Conn{}}) end)

      {_json, t_encode} = timed(fn -> Jason.encode!(rendered) end)

      stages =
        ([
           {"hash_to_transaction", t_fetch},
           {"preload_token_transfers", t_transfers},
           {"preload_participants", t_participants},
           {"preload_nft", t_nft},
           {"ENS + metadata preload", t_ens}
         ] ++
           ens_sub_stages ++
           [
             {"render total", t_render},
             {@sub_stage_prefix <> "block_height (cache)", t_height},
             {@sub_stage_prefix <> "decode_input", t_decode},
             {@sub_stage_prefix <> "address tags (batched)", t_tags},
             {"json encode", t_encode}
           ])
        |> Enum.reject(fn {_label, ms} -> is_nil(ms) end)

      if print?, do: print_stages(hash_string, stages)

      {:ok, Map.new(stages)}
    else
      {{:error, :not_found}, _time} ->
        if print?, do: IO.puts("transaction #{hash_string} not found")
        :not_found

      :error ->
        if print?, do: IO.puts("invalid transaction hash: #{hash_string}")
        :invalid_hash
    end
  end

  @doc """
  Profiles the `count` most recent transactions and prints avg/max per stage.
  """
  def run(count \\ 10) do
    hashes =
      Explorer.Repo.replica().all(
        from(t in Transaction,
          where: not is_nil(t.block_hash),
          order_by: [desc: t.block_number, desc: t.index],
          limit: ^count,
          select: t.hash
        )
      )

    results =
      hashes
      |> Enum.map(fn hash ->
        case profile(to_string(hash), print?: false) do
          {:ok, stages} -> stages
          _ -> nil
        end
      end)
      |> Enum.reject(&is_nil/1)

    if results == [] do
      IO.puts("no transactions profiled")
    else
      IO.puts("\n=== Transaction endpoint profiling (#{length(results)} transactions, avg / max ms) ===")

      stage_labels(results)
      |> Enum.each(fn label ->
        values = Enum.map(results, &Map.fetch!(&1, label))
        print_line(label, "#{format_ms(avg(values))} / #{format_ms(Enum.max(values))}")
      end)

      totals = Enum.map(results, &total_ms/1)
      IO.puts(String.duplicate("-", 60))
      print_line("TOTAL", "#{format_ms(avg(totals))} / #{format_ms(Enum.max(totals))}")
    end

    :ok
  end

  @doc """
  Profiles one transaction while recording every SQL query via Ecto telemetry,
  then prints totals (queue vs query vs decode time), per-repo sums, and the
  `top` slowest query shapes.

  By default only queries belonging to the profiled request are recorded
  (matched via the `$callers` process ancestry, which covers Ecto's parallel
  preload tasks). Pass `scope: :node` to record every query on the node during
  the run instead — useful as a load census on a busy pod.
  """
  def queries(hash_string, top \\ 15, opts \\ []) do
    table = :ets.new(:tx_profiler_queries, [:public, :duplicate_bag])
    handler_id = "tx-profiler-#{System.unique_integer([:positive])}"
    root = if Keyword.get(opts, :scope, :request) == :node, do: :node, else: self()

    :telemetry.attach_many(handler_id, @telemetry_events, &__MODULE__.handle_query_event/4, {table, root})

    try do
      profile(hash_string, print?: false)
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

  @doc """
  Measures connection setup to each microservice used by the ENS + metadata
  stage, phase by phase: DNS lookup, TCP connect, TLS handshake (isolated via
  socket upgrade), and HTTP time-to-first-byte on the established connection.

  The in-app HTTP client reuses pooled connections, so `profile/2` timings
  mostly exclude connection setup; this shows what a request pays on a cold
  connection and where (name resolution, network RTT, TLS, or the service
  itself).
  """
  def microservices do
    [
      {"BENS (ENS)", Explorer.MicroserviceInterfaces.BENS},
      {"Metadata", Explorer.MicroserviceInterfaces.Metadata}
    ]
    |> Enum.each(fn {label, module} ->
      case Explorer.Utility.Microservice.check_enabled(module) do
        :ok -> diagnose(label, Explorer.Utility.Microservice.base_url(module))
        _ -> IO.puts("\n#{label}: disabled")
      end
    end)

    :ok
  end

  @doc """
  Connection-phase diagnostics (DNS / TCP / TLS / TTFB) for an arbitrary URL,
  e.g. `TxProfiler.diagnose("sig-provider", "https://sig-provider.example.com")`.
  """
  def diagnose(label, url) do
    uri = URI.parse(url)
    host = String.to_charlist(uri.host)

    IO.puts("\n#{label} — #{url}")

    {dns_result, dns_ms} = timed(fn -> :inet.gethostbyname(host) end)

    with {:dns, {:ok, hostent}} <- {:dns, dns_result},
         ips = elem(hostent, 5),
         ip = List.first(ips),
         :ok <- print_line(@sub_stage_prefix <> "DNS lookup", "#{format_ms(dns_ms)} ms -> #{format_ips(ips)}"),
         {tcp_result, tcp_ms} = timed(fn -> :gen_tcp.connect(ip, uri.port, [:binary, active: false], 5_000) end),
         {:tcp, {:ok, tcp_socket}} <- {:tcp, tcp_result} do
      print_line(@sub_stage_prefix <> "TCP connect", "#{format_ms(tcp_ms)} ms (#{format_ips([ip])}:#{uri.port})")
      socket_diagnostics(uri, host, tcp_socket)
    else
      {:dns, {:error, reason}} -> print_line(@sub_stage_prefix <> "DNS lookup", "FAILED: #{inspect(reason)}")
      {:tcp, {:error, reason}} -> print_line(@sub_stage_prefix <> "TCP connect", "FAILED: #{inspect(reason)}")
    end
  end

  defp socket_diagnostics(%URI{scheme: "https"} = uri, host, tcp_socket) do
    {tls_result, tls_ms} =
      timed(fn -> :ssl.connect(tcp_socket, [verify: :verify_none, server_name_indication: host], 5_000) end)

    case tls_result do
      {:ok, ssl_socket} ->
        print_line(@sub_stage_prefix <> "TLS handshake", "#{format_ms(tls_ms)} ms")
        measure_ttfb(uri, &:ssl.send(ssl_socket, &1), fn -> :ssl.recv(ssl_socket, 0, 5_000) end)
        :ssl.close(ssl_socket)

      {:error, reason} ->
        print_line(@sub_stage_prefix <> "TLS handshake", "FAILED: #{inspect(reason)}")
        :gen_tcp.close(tcp_socket)
    end
  end

  defp socket_diagnostics(uri, _host, tcp_socket) do
    print_line(@sub_stage_prefix <> "TLS handshake", "n/a (http)")
    measure_ttfb(uri, &:gen_tcp.send(tcp_socket, &1), fn -> :gen_tcp.recv(tcp_socket, 0, 5_000) end)
    :gen_tcp.close(tcp_socket)
  end

  defp measure_ttfb(uri, send_fun, recv_fun) do
    request = "HEAD / HTTP/1.1\r\nHost: #{uri.host}\r\nConnection: close\r\n\r\n"

    {result, ms} =
      timed(fn ->
        with :ok <- send_fun.(request), do: recv_fun.()
      end)

    case result do
      {:ok, response} ->
        status_line = response |> IO.iodata_to_binary() |> String.split("\r\n") |> hd()
        print_line(@sub_stage_prefix <> "HTTP HEAD / (TTFB)", "#{format_ms(ms)} ms (#{status_line})")

      {:error, reason} ->
        print_line(@sub_stage_prefix <> "HTTP HEAD / (TTFB)", "FAILED: #{inspect(reason)}")
    end
  end

  defp format_ips(ips) do
    Enum.map_join(ips, ", ", fn ip -> ip |> :inet.ntoa() |> List.to_string() end)
  end

  # --- endpoint pipeline reconstruction -------------------------------------

  # Mirrors @transaction_necessity_by_association (plus the runtime additions)
  # in BlockScoutWeb.API.V2.TransactionController.transaction/2. Chain-type
  # compile-time extras (e.g. Celo gas token) are not replicated. On releases
  # that predate the unified participants preload, the per-association address
  # trees are used instead, matching the controller of those releases.
  defp transaction_necessity do
    base =
      if unified_participants_preload?() do
        %{:block => :optional, :signed_authorizations => :optional}
      else
        %{
          :block => :optional,
          [
            created_contract_address: [
              :scam_badge,
              :names,
              :token,
              smart_contract_association(),
              Implementation.proxy_implementations_association()
            ]
          ] => :optional,
          [
            from_address: [
              :scam_badge,
              :names,
              smart_contract_association(),
              Implementation.proxy_implementations_association()
            ]
          ] => :optional,
          [to_address: [:scam_badge, :names, :smart_contract, Implementation.proxy_implementations_association()]] =>
            :optional,
          :signed_authorizations => :optional
        }
      end

    case Application.get_env(:explorer, :chain_type) do
      :zksync ->
        base
        |> Map.put(:zksync_batch, :optional)
        |> Map.put(:zksync_commit_transaction, :optional)
        |> Map.put(:zksync_prove_transaction, :optional)
        |> Map.put(:zksync_execute_transaction, :optional)

      :arbitrum ->
        base
        |> Map.put(:arbitrum_batch, :optional)
        |> Map.put(:arbitrum_commitment_transaction, :optional)
        |> Map.put(:arbitrum_confirmation_transaction, :optional)
        |> Map.put(:arbitrum_message_to_l2, :optional)
        |> Map.put(:arbitrum_message_from_l2, :optional)

      :suave ->
        base
        |> Map.put(:logs, :optional)
        |> Map.put([execution_node: :names], :optional)
        |> Map.put([wrapped_to_address: :names], :optional)

      :eden ->
        Map.put(
          base,
          [
            fee_payer_address: [
              :scam_badge,
              :names,
              :smart_contract,
              Implementation.proxy_implementations_association()
            ]
          ],
          :optional
        )

      _ ->
        base
    end
  end

  # Mirrors @token_transfers_in_transaction_necessity_by_association.
  defp token_transfers_necessity do
    if unified_participants_preload?() do
      %{[token: Reputation.reputation_association()] => :optional}
    else
      address_preload = [
        :scam_badge,
        :names,
        smart_contract_association(),
        Implementation.proxy_implementations_association()
      ]

      %{
        [from_address: address_preload] => :optional,
        [to_address: address_preload] => :optional,
        [token: Reputation.reputation_association()] => :optional
      }
    end
  end

  # Mirrors @transaction_participants_necessity_by_association.
  defp participants_necessity do
    %{
      :scam_badge => :optional,
      :names => :optional,
      :token => :optional,
      smart_contract_association() => :optional,
      Implementation.proxy_implementations_association() => :optional
    }
  end

  defp unified_participants_preload? do
    function_exported?(Chain, :preload_transaction_participants, 3)
  end

  # Falls back to the full association on releases that predate the slim preload.
  defp smart_contract_association do
    if function_exported?(SmartContract, :association_without_abi, 0) do
      SmartContract.association_without_abi()
    else
      :smart_contract
    end
  end

  defp address_hashes(transaction) do
    [transaction.from_address_hash, transaction.to_address_hash, transaction.created_contract_address_hash]
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
  end

  # --- timing / reporting ----------------------------------------------------

  defp timed(fun) do
    start = System.monotonic_time(:microsecond)
    result = fun.()
    {result, (System.monotonic_time(:microsecond) - start) / 1000}
  end

  defp print_stages(hash_string, stages) do
    IO.puts("\n=== #{hash_string} ===")
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

  defp stage_labels([first | _]) do
    # preserve display order from profile/2
    [
      "hash_to_transaction",
      "preload_token_transfers",
      "preload_participants",
      "preload_nft",
      "ENS + metadata preload",
      @sub_stage_prefix <> "ENS lookup (BENS)",
      @sub_stage_prefix <> "metadata lookup",
      "render total",
      @sub_stage_prefix <> "block_height (cache)",
      @sub_stage_prefix <> "decode_input",
      @sub_stage_prefix <> "address tags (batched)",
      "json encode"
    ]
    |> Enum.filter(&Map.has_key?(first, &1))
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

  defp avg(values), do: Enum.sum(values) / length(values)

  defp format_ms(ms), do: :erlang.float_to_binary(ms / 1, decimals: 1)

  defp print_line(label, value), do: IO.puts(String.pad_trailing(label, 36) <> value)

  defp truncate(string, max) do
    string = String.replace(string, ~r/\s+/, " ")
    if String.length(string) > max, do: String.slice(string, 0, max) <> "...", else: string
  end
end
