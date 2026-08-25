# Profiles DB connection pool consumption node-wide from an IEx console:
# which SQL query shapes (and which caller processes) keep connections
# checked out the longest, plus live pool saturation sampling. Built for
# diagnosing "out of DB connections" incidents on the master DB.
#
# Usage on any pod (run it on the pod class that talks to the overloaded DB,
# e.g. an indexer pod for master-instance overload):
#
#   kubectl cp scripts/db_connections_profiler.exs <pod>:/tmp/db_connections_profiler.exs
#   kubectl exec -it <pod> -- bin/blockscout remote
#   iex> Code.eval_file("/tmp/db_connections_profiler.exs")
#   iex> DbConnectionsProfiler.pools()      # instant pool saturation snapshot
#   iex> DbConnectionsProfiler.run(30)      # 30s profiling window + report
#
# (Pasting the whole module into IEx works too.)
#
# All work is read-only; only aggregated counters are kept in memory
# (bounded by the number of distinct query shapes), so it is safe to run
# on a loaded production node.
defmodule DbConnectionsProfiler do
  @moduledoc """
  Node-wide profiler answering "which queries are eating our DB connections?".

  - `run/2` — records every Ecto query on the node for a time window and
    reports, per query shape, the total *connection hold* time (`query_time`,
    i.e. time a pool connection was checked out executing it — queue and
    decode excluded). `hold / window` is the average number of pool
    connections that shape kept busy. It also reports queue (checkout wait)
    time — the victims of pool exhaustion — and attributes hold time to
    caller processes.
  - `pools/0` — one-shot snapshot of every repo's pool: busy connections and
    processes waiting for a connection right now.
  """

  @default_window_s 30
  @default_sample_ms 250
  @default_top 20

  @doc """
  Profiles all running repos for `seconds`, then prints the report.

  Options:
  - `top: 20` — how many query shapes / callers to print
  - `sample_ms: 250` — pool saturation sampling interval
  - `repos: [Explorer.Repo]` — restrict to specific repos (default: all running)
  - `callers: true` — attribute hold time to caller processes (small extra
    cost per query event; pass `false` to disable)
  - `sql_chars: 130` — SQL truncation width in the report
  """
  def run(seconds \\ @default_window_s, opts \\ []) do
    repos = profiled_repos(opts)

    if repos == [] do
      IO.puts("no running Ecto repos found")
    else
      do_run(repos, seconds, opts)
    end
  end

  @doc """
  Prints the current pool state of every running repo: pool size, busy
  connections (approximated as `pool_size - ready`) and the number of
  processes currently waiting for a connection.
  """
  def pools(opts \\ []) do
    IO.puts("\nrepo                                     pool   busy   waiting")

    Enum.each(profiled_repos(opts), fn {repo, _event, pool, pool_size} ->
      case pool_metrics(pool) do
        {ready, waiting} ->
          line =
            String.pad_trailing(inspect(repo), 40) <>
              pad_num(pool_size, 5) <> pad_num(max(pool_size - ready, 0), 7) <> pad_num(waiting, 10)

          IO.puts(line)

        :error ->
          IO.puts(String.pad_trailing(inspect(repo), 40) <> "  (pool metrics unavailable)")
      end
    end)

    :ok
  end

  # --- profiling window ------------------------------------------------------

  defp do_run(repos, seconds, opts) do
    top = Keyword.get(opts, :top, @default_top)
    sample_ms = Keyword.get(opts, :sample_ms, @default_sample_ms)
    callers? = Keyword.get(opts, :callers, true)
    sql_chars = Keyword.get(opts, :sql_chars, 130)

    shapes = :ets.new(:db_conn_profiler_shapes, [:public, :set, {:write_concurrency, true}])
    callers = :ets.new(:db_conn_profiler_callers, [:public, :set, {:write_concurrency, true}])
    labels = :ets.new(:db_conn_profiler_labels, [:public, :set, {:read_concurrency, true}])
    samples = :ets.new(:db_conn_profiler_samples, [:public, :set])

    events = repos |> Enum.map(fn {_repo, event, _pool, _size} -> event end) |> Enum.uniq()
    handler_id = "db-conn-profiler-#{System.unique_integer([:positive])}"

    :telemetry.attach_many(
      handler_id,
      events,
      &__MODULE__.handle_query_event/4,
      {shapes, callers, labels, callers?}
    )

    sampler = spawn(fn -> sample_loop(repos, samples, sample_ms) end)

    IO.puts("profiling #{length(repos)} repos for #{seconds}s ...")
    started = System.monotonic_time(:millisecond)

    try do
      Process.sleep(seconds * 1000)
    after
      :telemetry.detach(handler_id)
      send(sampler, :stop)
    end

    window_ms = System.monotonic_time(:millisecond) - started

    shape_rows = :ets.tab2list(shapes)
    caller_rows = :ets.tab2list(callers)
    sample_rows = :ets.tab2list(samples)
    Enum.each([shapes, callers, labels, samples], &:ets.delete/1)

    print_report(repos, window_ms, shape_rows, caller_rows, sample_rows, top, callers?, sql_chars)
  end

  @doc false
  def handle_query_event(_event, measurements, metadata, {shapes, callers, labels, callers?}) do
    hold = to_us(measurements[:query_time])
    queue = to_us(measurements[:queue_time])
    decode = to_us(measurements[:decode_time])

    shape_key = {metadata.repo, metadata.source, metadata.query}

    # last op keeps a max: stored value is -(max hold so far); with Incr 0,
    # `current > -hold` (i.e. max_so_far < hold) resets it to -hold
    :ets.update_counter(
      shapes,
      shape_key,
      [{2, 1}, {3, hold}, {4, queue}, {5, decode}, {6, 0, -hold, -hold}],
      {shape_key, 0, 0, 0, 0, 0}
    )

    if callers? do
      caller_key = {metadata.repo, caller_label(labels)}
      :ets.update_counter(callers, caller_key, [{2, 1}, {3, hold}, {4, queue}], {caller_key, 0, 0, 0})
    end
  end

  # --- caller attribution ------------------------------------------------------

  # The telemetry handler runs in the process that issued the query; for Ecto's
  # parallel preload tasks `$callers` leads back to the originating process.
  defp caller_label(labels) do
    pid =
      case Process.get(:"$callers") do
        [_ | _] = list -> List.last(list)
        _ -> self()
      end

    case :ets.lookup(labels, pid) do
      [{^pid, label}] ->
        label

      [] ->
        label = compute_label(pid)
        :ets.insert(labels, {pid, label})
        label
    end
  end

  defp compute_label(pid) do
    with :none <- registered_name(pid),
         :none <- dictionary_initial_call(pid),
         :none <- plain_initial_call(pid) do
      :unknown
    end
  end

  defp registered_name(pid) do
    case Process.info(pid, :registered_name) do
      {:registered_name, name} when is_atom(name) and name != nil -> name
      _ -> :none
    end
  end

  # for proc_lib processes (GenServers etc.) this is the real callback module
  defp dictionary_initial_call(pid) do
    case Process.info(pid, :dictionary) do
      {:dictionary, dict} ->
        case List.keyfind(dict, :"$initial_call", 0) do
          {_, {mod, fun, arity}} -> "#{inspect(mod)}.#{fun}/#{arity}"
          _ -> :none
        end

      _ ->
        :none
    end
  end

  defp plain_initial_call(pid) do
    case Process.info(pid, :initial_call) do
      {:initial_call, {mod, fun, arity}} -> "#{inspect(mod)}.#{fun}/#{arity}"
      _ -> :none
    end
  end

  # --- pool saturation sampling ------------------------------------------------

  defp sample_loop(repos, samples, interval) do
    receive do
      :stop -> :ok
    after
      interval ->
        Enum.each(repos, fn {repo, _event, pool, pool_size} ->
          case pool_metrics(pool) do
            {ready, waiting} ->
              busy = max(pool_size - ready, 0)
              saturated = if ready == 0, do: 1, else: 0

              case :ets.lookup(samples, repo) do
                [{^repo, n, busy_sum, busy_max, wait_sum, wait_max, sat}] ->
                  :ets.insert(
                    samples,
                    {repo, n + 1, busy_sum + busy, max(busy_max, busy), wait_sum + waiting, max(wait_max, waiting),
                     sat + saturated}
                  )

                [] ->
                  :ets.insert(samples, {repo, 1, busy, busy, waiting, waiting, saturated})
              end

            :error ->
              :ok
          end
        end)

        sample_loop(repos, samples, interval)
    end
  end

  defp pool_metrics(pool) do
    pool
    |> DBConnection.get_connection_metrics()
    |> Enum.reduce({0, 0}, fn %{ready_conn_count: ready, checkout_queue_length: waiting}, {r, w} ->
      {r + ready, w + waiting}
    end)
  catch
    _, _ -> :error
  end

  # --- repo discovery ------------------------------------------------------------

  defp profiled_repos(opts) do
    opts
    |> Keyword.get_lazy(:repos, fn -> Enum.filter(Ecto.Repo.all_running(), &is_atom/1) end)
    |> Enum.flat_map(fn repo ->
      case repo_meta(repo) do
        {:ok, event, pool} -> [{repo, event, pool, repo.config()[:pool_size] || 10}]
        :error -> []
      end
    end)
  end

  defp repo_meta(repo) do
    case Ecto.Adapter.lookup_meta(repo) do
      %{pid: pool, telemetry: {_repo, _log, event}} when is_list(event) -> {:ok, event, pool}
      _ -> :error
    end
  catch
    _, _ -> :error
  end

  # --- reporting -------------------------------------------------------------------

  defp print_report(repos, window_ms, shape_rows, caller_rows, sample_rows, top, callers?, sql_chars) do
    IO.puts(
      "\n=== DB connection profile: #{format_ms(window_ms / 1)} ms window, #{length(shape_rows)} query shapes ==="
    )

    print_pool_samples(repos, sample_rows)
    print_repo_totals(shape_rows, window_ms)
    print_top_shapes(shape_rows, window_ms, top, sql_chars)
    if callers?, do: print_top_callers(caller_rows, window_ms, top)

    IO.puts("")
    IO.puts("hold      = time a pool connection was checked out executing the query (queue/decode excluded)")
    IO.puts("~conns    = hold / window: average pool connections this row kept busy — the culprits rank here")
    IO.puts("queue     = time callers waited for a free connection — pool-exhaustion victims rank here")
    :ok
  end

  defp print_pool_samples(_repos, []) do
    IO.puts("\n(no pool saturation samples collected)")
  end

  defp print_pool_samples(repos, sample_rows) do
    IO.puts("\npool saturation (sampled; busy ~= pool_size - ready):")
    IO.puts("repo                                     pool   busy avg/max     waiting avg/max   saturated")

    sizes = Map.new(repos, fn {repo, _e, _p, size} -> {repo, size} end)

    sample_rows
    |> Enum.sort_by(fn {_repo, n, busy_sum, _bm, _ws, _wm, _sat} -> -busy_sum / max(n, 1) end)
    |> Enum.each(fn {repo, n, busy_sum, busy_max, wait_sum, wait_max, sat} ->
      IO.puts(
        String.pad_trailing(inspect(repo), 40) <>
          pad_num(Map.get(sizes, repo, "?"), 5) <>
          String.pad_leading("#{Float.round(busy_sum / n, 1)} / #{busy_max}", 15) <>
          String.pad_leading("#{Float.round(wait_sum / n, 1)} / #{wait_max}", 20) <>
          String.pad_leading("#{round(100 * sat / n)}%", 11)
      )
    end)
  end

  defp print_repo_totals(shape_rows, window_ms) do
    IO.puts("\nper-repo query load:")
    IO.puts("repo                                    queries   hold total ms   ~conns   queue total ms")

    shape_rows
    |> Enum.group_by(fn {{repo, _s, _q}, _n, _h, _qu, _d, _m} -> repo end)
    |> Enum.map(fn {repo, rows} ->
      {repo, sum_pos(rows, 1), sum_pos(rows, 2) / 1000, sum_pos(rows, 3) / 1000}
    end)
    |> Enum.sort_by(fn {_repo, _n, hold, _queue} -> -hold end)
    |> Enum.each(fn {repo, n, hold, queue} ->
      IO.puts(
        String.pad_trailing(inspect(repo), 40) <>
          pad_num(n, 7) <>
          String.pad_leading(format_ms(hold), 16) <>
          String.pad_leading(format_conns(hold / window_ms), 9) <>
          String.pad_leading(format_ms(queue), 17)
      )
    end)
  end

  defp print_top_shapes(shape_rows, window_ms, top, sql_chars) do
    IO.puts("\ntop #{top} query shapes by connection hold time:")

    shape_rows
    |> Enum.sort_by(fn {_key, _n, hold, _queue, _decode, _neg_max} -> -hold end)
    |> Enum.take(top)
    |> Enum.each(fn {{repo, source, query}, n, hold_us, queue_us, _decode_us, neg_max_us} ->
      hold = hold_us / 1000

      IO.puts(
        String.pad_leading(format_ms(hold), 10) <>
          " ms  ~conns=" <>
          String.pad_trailing(format_conns(hold / window_ms), 6) <>
          " n=" <>
          String.pad_trailing(to_string(n), 6) <>
          " avg=" <>
          String.pad_trailing(format_ms(hold / max(n, 1)), 8) <>
          " max=" <>
          String.pad_trailing(format_ms(-neg_max_us / 1000), 9) <>
          " queue=" <>
          String.pad_trailing(format_ms(queue_us / 1000), 9) <>
          " #{short_repo(repo)} #{source || "-"} | #{truncate(query, sql_chars)}"
      )
    end)
  end

  defp print_top_callers(caller_rows, window_ms, top) do
    IO.puts("\ntop #{top} callers by connection hold time:")

    caller_rows
    |> Enum.group_by(fn {{_repo, label}, _n, _h, _q} -> label end)
    |> Enum.map(fn {label, rows} ->
      {label, sum_pos(rows, 1), sum_pos(rows, 2) / 1000, sum_pos(rows, 3) / 1000}
    end)
    |> Enum.sort_by(fn {_label, _n, hold, _queue} -> -hold end)
    |> Enum.take(top)
    |> Enum.each(fn {label, n, hold, queue} ->
      IO.puts(
        String.pad_leading(format_ms(hold), 10) <>
          " ms  ~conns=" <>
          String.pad_trailing(format_conns(hold / window_ms), 6) <>
          " n=" <>
          String.pad_trailing(to_string(n), 6) <>
          " queue=" <>
          String.pad_trailing(format_ms(queue), 9) <>
          " #{format_label(label)}"
      )
    end)
  end

  # sums element at `offset` positions after the key in aggregate tuples
  defp sum_pos(rows, offset), do: rows |> Enum.map(&elem(&1, offset)) |> Enum.sum()

  defp to_us(nil), do: 0
  defp to_us(native), do: System.convert_time_unit(native, :native, :microsecond)

  defp format_ms(ms), do: :erlang.float_to_binary(ms / 1, decimals: 1)

  defp format_conns(ratio), do: :erlang.float_to_binary(ratio / 1, decimals: 2)

  defp format_label(label) when is_atom(label), do: inspect(label)
  defp format_label(label), do: label

  defp short_repo(repo), do: repo |> inspect() |> String.replace_prefix("Explorer.", "")

  defp pad_num(value, width), do: String.pad_leading(to_string(value), width)

  defp truncate(string, max) do
    string = String.replace(string, ~r/\s+/, " ")
    if String.length(string) > max, do: String.slice(string, 0, max) <> "...", else: string
  end
end
