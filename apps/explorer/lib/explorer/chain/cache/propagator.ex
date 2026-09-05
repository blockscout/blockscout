# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Chain.Cache.Propagator do
  @moduledoc """
  Propagates cache writes from indexer nodes to the other nodes of the cluster.

  `Explorer.Chain.OrderedCache` and `Explorer.Chain.MapCache` write to their local
  `ConCache` synchronously and then hand the written data to this process. The
  process coalesces pending writes per cache and ships them to `Node.list/0` with
  `:erpc.multicast/4` from a short-lived sender process, so that:

  - the local write never depends on the state of a remote node or of the
    distribution link. Before this process existed the multicast ran inside the
    block import task and, when the distribution buffer to an API node was full,
    the VM suspended the task: tens of thousands of tasks piled up holding
    preloaded blocks and transactions, and the indexer's own caches stalled;
  - at most one batch is in flight at any time and the pending data is bounded.
    Ordered caches keep at most `max_size` newest elements, map caches keep only
    the set of dirty keys (the current local value is read when the batch is
    sent), so a slow cluster only makes API nodes skip intermediate states;
  - a sender that stays blocked (e.g. suspended on a busy distribution port) is
    killed after `send_timeout` and its batch is dropped.

  Ordered caches are expected to hand over elements already stripped of their
  heavy associations (see `Explorer.Chain.OrderedCache.strip_for_propagation/1`);
  the receiving node loads them back from its replica database.

  ## Configuration

  - `:flush_interval` - how long (ms) writes are accumulated before a batch is
    sent, defaults to 100. A batch is never sent while another one is in flight.
  - `:send_timeout` - how long (ms) a sender may take before it is killed and its
    batch dropped, defaults to 30 seconds.
  """

  use GenServer

  require Logger

  @default_flush_interval 100
  @default_send_timeout :timer.seconds(30)

  @typep pending_key :: {:ordered, module()} | {:map, module()}
  @type pending :: %{optional(pending_key) => [{term(), struct()}] | MapSet.t(atom())}

  ## Client

  @doc """
  Starts the propagator.

  Besides `:name`, `:flush_interval` and `:send_timeout`, the following options
  exist for tests: `:nodes_fun` (a zero-arity function returning the nodes to
  propagate to, defaults to `Node.list/0`) and `:multicast_fun` (a 4-arity
  function with the signature of `:erpc.multicast/4`).
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    {name, opts} = Keyword.pop(opts, :name, __MODULE__)
    gen_server_opts = if name, do: [name: name], else: []

    GenServer.start_link(__MODULE__, opts, gen_server_opts)
  end

  @doc """
  Queues prepared `{id, element}` pairs of an `Explorer.Chain.OrderedCache` for
  propagation. Only the `max_size` most prevailing pending elements are kept.
  """
  @spec enqueue_ordered(module(), [{term(), struct()}], GenServer.server()) :: :ok
  def enqueue_ordered(cache_module, prepared_elements, server \\ __MODULE__) do
    GenServer.cast(server, {:ordered, cache_module, prepared_elements})
  end

  @doc """
  Marks keys of an `Explorer.Chain.MapCache` as dirty. Their current local values
  are read and propagated when the next batch is sent.
  """
  @spec enqueue_map(module(), atom() | [atom()], GenServer.server()) :: :ok
  def enqueue_map(cache_module, keys, server \\ __MODULE__) do
    GenServer.cast(server, {:map, cache_module, List.wrap(keys)})
  end

  @doc """
  Returns the data queued but not yet sent, for introspection and tests.
  """
  @spec pending(GenServer.server()) :: pending()
  def pending(server \\ __MODULE__), do: GenServer.call(server, :pending)

  @doc """
  Sends the pending data right away instead of waiting for the flush interval.
  Does nothing while a batch is already in flight.
  """
  @spec flush(GenServer.server()) :: :ok
  def flush(server \\ __MODULE__), do: GenServer.call(server, :flush)

  @doc false
  # Merges new prepared elements into the pending ones: newest version of an id
  # wins, the result is ordered by `prevails?/2` and capped to `max_size/0`.
  @spec coalesce_ordered(module(), [{term(), struct()}], [{term(), struct()}]) :: [{term(), struct()}]
  def coalesce_ordered(cache_module, existing, new) do
    (new ++ existing)
    |> Enum.uniq_by(&elem(&1, 0))
    |> Enum.sort_by(&elem(&1, 0), &cache_module.prevails?/2)
    |> Enum.take(cache_module.max_size())
  end

  ## Server

  @impl GenServer
  def init(opts) do
    config = Application.get_env(:explorer, __MODULE__, [])

    state = %{
      pending: %{},
      in_flight: nil,
      flush_timer: nil,
      flush_interval: opts[:flush_interval] || config[:flush_interval] || @default_flush_interval,
      send_timeout: opts[:send_timeout] || config[:send_timeout] || @default_send_timeout,
      nodes_fun: opts[:nodes_fun] || (&Node.list/0),
      multicast_fun: opts[:multicast_fun] || (&:erpc.multicast/4)
    }

    {:ok, state}
  end

  @impl GenServer
  def handle_cast({:ordered, cache_module, prepared_elements}, state) do
    pending =
      Map.update(
        state.pending,
        {:ordered, cache_module},
        coalesce_ordered(cache_module, [], prepared_elements),
        &coalesce_ordered(cache_module, &1, prepared_elements)
      )

    {:noreply, schedule_flush(%{state | pending: pending})}
  end

  def handle_cast({:map, cache_module, keys}, state) do
    new_keys = MapSet.new(keys)
    pending = Map.update(state.pending, {:map, cache_module}, new_keys, &MapSet.union(&1, new_keys))

    {:noreply, schedule_flush(%{state | pending: pending})}
  end

  @impl GenServer
  def handle_call(:pending, _from, state), do: {:reply, state.pending, state}

  def handle_call(:flush, _from, state) do
    {:reply, :ok, state |> cancel_flush_timer() |> do_flush()}
  end

  @impl GenServer
  def handle_info(:flush, state) do
    {:noreply, do_flush(%{state | flush_timer: nil})}
  end

  def handle_info({:DOWN, ref, :process, _pid, reason}, %{in_flight: %{ref: ref} = in_flight} = state) do
    Process.cancel_timer(in_flight.timer)
    log_sender_exit(reason, in_flight)

    {:noreply, schedule_flush(%{state | in_flight: nil})}
  end

  def handle_info({:sender_timeout, ref}, %{in_flight: %{ref: ref} = in_flight} = state) do
    Logger.warning(fn ->
      [
        "Cache propagation to ",
        inspect(in_flight.nodes),
        " did not complete in ",
        to_string(state.send_timeout),
        "ms, dropping the batch: ",
        inspect(in_flight.summary)
      ]
    end)

    Process.exit(in_flight.pid, :kill)

    {:noreply, state}
  end

  def handle_info(_message, state), do: {:noreply, state}

  ## Internals

  defp schedule_flush(%{pending: pending} = state) when map_size(pending) == 0, do: state

  defp schedule_flush(%{flush_timer: nil} = state) do
    %{state | flush_timer: Process.send_after(self(), :flush, state.flush_interval)}
  end

  defp schedule_flush(state), do: state

  defp cancel_flush_timer(%{flush_timer: nil} = state), do: state

  defp cancel_flush_timer(%{flush_timer: timer} = state) do
    Process.cancel_timer(timer)
    %{state | flush_timer: nil}
  end

  defp do_flush(%{pending: pending} = state) when map_size(pending) == 0, do: state

  # A batch is being sent: pending data keeps coalescing and the sender's exit
  # schedules the next flush.
  defp do_flush(%{in_flight: %{}} = state), do: state

  defp do_flush(state) do
    case state.nodes_fun.() do
      [] ->
        # Nothing to propagate to. Nodes joining later start from the database
        # fallbacks of their caches and catch up with the following writes.
        %{state | pending: %{}}

      nodes ->
        batch = state.pending
        multicast_fun = state.multicast_fun

        {pid, ref} = spawn_monitor(fn -> send_batch(batch, nodes, multicast_fun) end)
        timer = Process.send_after(self(), {:sender_timeout, ref}, state.send_timeout)

        in_flight = %{pid: pid, ref: ref, timer: timer, nodes: nodes, summary: summarize(batch)}

        %{state | pending: %{}, in_flight: in_flight}
    end
  end

  defp send_batch(batch, nodes, multicast_fun) do
    Enum.each(batch, fn
      {{:ordered, cache_module}, prepared_elements} ->
        multicast_fun.(nodes, cache_module, :do_raw_update, [prepared_elements, false])

      {{:map, cache_module}, keys} ->
        values = cache_module.current_values(MapSet.to_list(keys))
        multicast_fun.(nodes, cache_module, :apply_propagated, [values])
    end)
  end

  defp summarize(batch) do
    Map.new(batch, fn
      {{:ordered, cache_module}, prepared_elements} -> {cache_module, length(prepared_elements)}
      {{:map, cache_module}, keys} -> {cache_module, MapSet.to_list(keys)}
    end)
  end

  defp log_sender_exit(:normal, _in_flight), do: :ok
  # already reported by the timeout handler
  defp log_sender_exit(:killed, _in_flight), do: :ok

  defp log_sender_exit(reason, in_flight) do
    Logger.error(fn ->
      ["Cache propagation to ", inspect(in_flight.nodes), " failed: ", inspect(reason)]
    end)
  end
end
