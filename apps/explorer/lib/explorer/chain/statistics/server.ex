defmodule Explorer.Chain.Statistics.Server do
  @moduledoc "Stores the latest chain statistics."

  use GenServer

  require Logger

  alias Explorer.Chain.Statistics

  @interval 1_000

  defstruct statistics: %Statistics{},
            task: nil

  def child_spec(_) do
    Supervisor.Spec.worker(__MODULE__, [[refresh: true]])
  end

  @spec fetch() :: Statistics.t()
  def fetch do
    GenServer.call(__MODULE__, :fetch)
  end

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl GenServer
  def init(options) when is_list(options) do
    if Keyword.get(options, :refresh, true) do
      send(self(), :refresh)
    end

    {:ok, %__MODULE__{}}
  end

  @impl GenServer

  def handle_info(:refresh, %__MODULE__{task: task} = state) do
    new_state =
      case task do
        nil ->
          %__MODULE__{state | task: Task.Supervisor.async_nolink(Explorer.TaskSupervisor, Statistics, :fetch, [])}

        _ ->
          state
      end

    {:noreply, new_state}
  end

  def handle_info({ref, %Statistics{} = statistics}, %__MODULE__{task: %Task{ref: ref}} = state) do
    Process.demonitor(ref, [:flush])
    Process.send_after(self(), :refresh, @interval)

    {:noreply, %__MODULE__{state | statistics: statistics, task: nil}}
  end

  def handle_info({:DOWN, ref, :process, pid, reason}, %__MODULE__{task: %Task{pid: pid, ref: ref}} = state) do
    Logger.error(fn -> "#{inspect(Statistics)}.fetch failed and could not be cached: #{inspect(reason)}" end)

    Process.send_after(self(), :refresh, @interval)

    {:noreply, %__MODULE__{state | task: nil}}
  end

  @impl GenServer
  def handle_call(:fetch, _, %__MODULE__{statistics: %Statistics{} = statistics} = state),
    do: {:reply, statistics, state}

  @impl GenServer
  def terminate(_, %__MODULE__{task: nil}), do: :ok

  def terminate(_, %__MODULE__{task: task}) do
    Task.shutdown(task)
  end
end
