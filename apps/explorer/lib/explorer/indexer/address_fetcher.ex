defmodule Explorer.Indexer.AddressFetcher do
  @moduledoc """
  Fetches and indexes `t:Explorer.Chain.Address.t/0` balances.
  """
  use GenServer
  require Logger

  alias Explorer.{Chain, JSONRPC}

  alias Explorer.Chain.{
    Address,
    Hash
  }

  @fetch_interval :timer.seconds(3)
  @max_batch_size 100
  @max_concurrency 2

  def async_fetch_balances(address_hashes) do
    GenServer.cast(__MODULE__, {:buffer_addresses, address_hashes})
  end

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(opts) do
    opts = Keyword.merge(Application.fetch_env!(:explorer, :indexer), opts)
    send(self(), :fetch_unfetched_addresses)

    state = %{
      debug_logs: Keyword.get(opts, :debug_logs, false),
      flush_timer: nil,
      fetch_interval: Keyword.get(opts, :fetch_interval, @fetch_interval),
      max_batch_size: Keyword.get(opts, :max_batch_size, @max_batch_size),
      buffer: :queue.new(),
      tasks: %{}
    }

    {:ok, state}
  end

  def handle_info(:fetch_unfetched_addresses, state) do
    {:noreply, stream_unfetched_addresses(state)}
  end

  def handle_info(:flush, state) do
    {:noreply, state |> fetch_next_batch([]) |> schedule_next_buffer_flush()}
  end

  def handle_info({:async_fetch, hashes}, state) do
    {:noreply, fetch_next_batch(state, hashes)}
  end

  def handle_info({ref, {:fetched_balances, results}}, state) do
    :ok = Chain.update_balances(results)
    {:noreply, drop_task(state, ref)}
  end

  def handle_info({:DOWN, _ref, :process, _pid, :normal}, state) do
    {:noreply, state}
  end

  def handle_info({:DOWN, ref, :process, _pid, _reason}, state) do
    batch = Map.fetch!(state.tasks, ref)

    new_state =
      state
      |> drop_task(ref)
      |> buffer_addresses(batch)

    {:noreply, new_state}
  end

  def handle_cast({:buffer_addresses, address_hashes}, state) do
    string_hashes = for hash <- address_hashes, do: Hash.to_string(hash)
    {:noreply, buffer_addresses(state, string_hashes)}
  end

  defp drop_task(state, ref) do
    schedule_async_fetch([])
    %{state | tasks: Map.delete(state.tasks, ref)}
  end

  defp buffer_addresses(state, string_hashes) do
    %{state | buffer: :queue.join(state.buffer, :queue.from_list(string_hashes))}
  end

  defp stream_unfetched_addresses(state) do
    state.buffer
    |> Chain.stream_unfetched_addresses(fn %Address{hash: hash}, batch ->
      batch = :queue.in(Hash.to_string(hash), batch)

      if :queue.len(batch) >= state.max_batch_size do
        schedule_async_fetch(:queue.to_list(batch))
        :queue.new()
      else
        batch
      end
    end)
    |> fetch_remaining()

    schedule_next_buffer_flush(state)
  end

  defp fetch_remaining({:ok, batch}) do
    if :queue.len(batch) > 0 do
      schedule_async_fetch(:queue.to_list(batch))
    end

    :ok
  end

  defp do_fetch_addresses(address_hashes) do
    JSONRPC.fetch_balances_by_hash(address_hashes)
  end

  defp take_batch(queue) do
    {hashes, remaining_queue} =
      Enum.reduce_while(1..@max_batch_size, {[], queue}, fn _, {hashes, queue_acc} ->
        case :queue.out(queue_acc) do
          {{:value, hash}, new_queue} -> {:cont, {[hash | hashes], new_queue}}
          {:empty, new_queue} -> {:halt, {hashes, new_queue}}
        end
      end)

    {Enum.reverse(hashes), remaining_queue}
  end

  defp schedule_async_fetch(hashes, after_ms \\ 0) do
    Process.send_after(self(), {:async_fetch, hashes}, after_ms)
  end

  defp schedule_next_buffer_flush(state) do
    timer = Process.send_after(self(), :flush, state.fetch_interval)
    %{state | flush_timer: timer}
  end

  defp fetch_next_batch(state, hashes) do
    state = buffer_addresses(state, hashes)

    if Enum.count(state.tasks) < @max_concurrency and :queue.len(state.buffer) > 0 do
      {batch, new_queue} = take_batch(state.buffer)

      task =
        Task.Supervisor.async_nolink(Explorer.Indexer.TaskSupervisor, fn ->
          debug(state, fn -> "fetching #{Enum.count(batch)} balances" end)
          {:ok, balances} = do_fetch_addresses(batch)
          {:fetched_balances, balances}
        end)

      %{state | tasks: Map.put(state.tasks, task.ref, batch), buffer: new_queue}
    else
      buffer_addresses(state, hashes)
    end
  end

  defp debug(%{debug_logs: true}, func), do: Logger.debug(func)
  defp debug(%{debug_logs: false}, _func), do: :noop
end
