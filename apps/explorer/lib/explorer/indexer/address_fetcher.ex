defmodule Explorer.Indexer.AddressFetcher do
  @moduledoc """
  TODO
  """
  use GenServer
  require Logger

  alias Explorer.Chain
  alias Explorer.Chain.{
    Address,
    Hash,
  }
  alias Explorer.JSONRPC

  @fetch_interval :timer.seconds(3)
  @max_batch_size 500

  def async_fetch_addresses(address_hashes) do
    GenServer.cast(__MODULE__, {:buffer_addresses, address_hashes})
  end

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(_opts) do
    send(self(), :fetch_unfetched_addresses)

    {:ok, %{buffer: MapSet.new(), tasks: %{}}}
  end

  def handle_info(:fetch_unfetched_addresses, state) do
    schedule_next_buffer_fetch(0)
    {:noreply, stream_unfetched_addresses(state)}
  end

  def handle_info(:buffer_fetch, state) do
    schedule_next_buffer_fetch()
    {:noreply, flush_buffer(state)}
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
    {:noreply, buffer_addresses(state, address_hashes)}
  end

  defp drop_task(state, ref) do
    %{state | tasks: Map.delete(state.tasks, ref)}
  end

  defp buffer_addresses(state, address_hashes) do
    string_hashes = for hash <- address_hashes, do: Hash.to_string(hash)
    %{state | buffer: MapSet.union(state.buffer, MapSet.new(string_hashes))}
  end

  defp stream_unfetched_addresses(state) do
    tasks =
      {state.tasks, state.buffer}
      |> Chain.stream_unfetched_addresses(fn %Address{hash: hash}, {tasks, batch} ->
        batch = MapSet.put(batch, Hash.to_string(hash))
        if MapSet.size(batch) >= @max_batch_size do
          task = async_fetch_balances(batch)
          {Map.put(tasks, task.ref, batch), MapSet.new()}
        else
          {tasks, batch}
        end
      end)
      |> fetch_remaining()

    %{state | tasks: tasks}
  end
  defp fetch_remaining({:ok, {tasks, batch}}) do
    if MapSet.size(batch) > 0 do
      task = async_fetch_balances(batch)
      Map.put(tasks, task.ref, batch)
    else
      tasks
    end
  end

  defp flush_buffer(state) do
    if MapSet.size(state.buffer) > 0 do
      task = async_fetch_balances(state.buffer)
      new_tasks = Map.put(state.tasks, task.ref, state.buffer)

      %{state | tasks: new_tasks, buffer: MapSet.new()}
    else
      state
    end
  end

  defp schedule_next_buffer_fetch(after_ms \\ @fetch_interval) do
    Process.send_after(self(), :buffer_fetch, after_ms)
  end

  defp do_fetch_addresses(address_hashes) do
    JSONRPC.fetch_balances_by_hash(address_hashes)
  end

  defp async_fetch_balances(hashes_mapset) do
    Task.Supervisor.async_nolink(Explorer.Indexer.TaskSupervisor, fn ->
      Logger.debug(fn -> "fetching #{MapSet.size(hashes_mapset)} balances" end)
      {:ok, balances} = do_fetch_addresses(Enum.to_list(hashes_mapset))
      {:fetched_balances, balances}
    end)
  end
end
