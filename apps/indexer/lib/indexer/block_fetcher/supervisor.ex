defmodule Indexer.BlockFetcher.Supervisor do
  @moduledoc """
  Supervises the `Indexer.BlockerFetcher.Catchup` and `Indexer.BlockFetcher.Realtime`.
  """

  # NOT a `Supervisor` because of the `Task` restart strategies are custom.
  use GenServer

  require Logger

  alias Indexer.BlockFetcher
  alias Indexer.BlockFetcher.{Catchup, Realtime}

  def child_spec(arg) do
    # The `child_spec` from `use Supervisor` because the one from `use GenServer` will set the `type` to `:worker`
    # instead of `:supervisor` and use the wrong shutdown timeout
    Supervisor.child_spec(%{id: __MODULE__, start: {__MODULE__, :start_link, [arg]}, type: :supervisor}, [])
  end

  @doc """
  Starts supervisor of `Indexer.BlockerFetcher.Catchup` and `Indexer.BlockFetcher.Realtime`.

  For `named_arguments` see `Indexer.BlockFetcher.new/1`.  For `t:GenServer.options/0` see `GenServer.start_link/3`.
  """
  @spec start_link([named_arguments :: list() | GenServer.options()]) :: {:ok, pid}
  def start_link([named_arguments, gen_server_options]) when is_list(named_arguments) and is_list(gen_server_options) do
    GenServer.start_link(__MODULE__, named_arguments, gen_server_options)
  end

  @impl GenServer
  def init(named_arguments) do
    state = BlockFetcher.new(named_arguments)

    send(self(), :catchup_index)
    {:ok, _} = :timer.send_interval(state.realtime_interval, :realtime_index)

    {:ok, state}
  end

  @impl GenServer
  def handle_info(:catchup_index, %BlockFetcher{} = state) do
    {:noreply, Catchup.put(state)}
  end

  def handle_info({ref, _} = message, %BlockFetcher{catchup_task: %Task{ref: ref}} = state) do
    {:noreply, Catchup.handle_success(message, state)}
  end

  def handle_info(
        {:DOWN, ref, :process, pid, _} = message,
        %BlockFetcher{catchup_task: %Task{pid: pid, ref: ref}} = state
      ) do
    {:noreply, Catchup.handle_failure(message, state)}
  end

  def handle_info(:realtime_index, %BlockFetcher{} = state) do
    {:noreply, Realtime.put(state)}
  end

  def handle_info({ref, :ok} = message, %BlockFetcher{} = state) when is_reference(ref) do
    {:noreply, Realtime.handle_success(message, state)}
  end

  def handle_info({:DOWN, _, :process, _, _} = message, %BlockFetcher{} = state) do
    {:noreply, Realtime.handle_failure(message, state)}
  end
end
