defmodule Indexer.Block.Catchup.BoundIntervalSupervisor do
  @moduledoc """
  Supervises the `Indexer.BlockerFetcher.Catchup` with exponential backoff for restarts.
  """

  # NOT a `Supervisor` because of the `Task` restart strategies are custom.
  use GenServer

  require Logger

  alias Indexer.{Block, BoundInterval}
  alias Indexer.Block.Catchup

  @type named_arguments :: %{
          required(:block_fetcher) => Block.Fetcher.t(),
          optional(:block_interval) => pos_integer,
          optional(:memory_monitor) => GenServer.server()
        }

  # milliseconds
  @block_interval 5_000

  @enforce_keys ~w(bound_interval fetcher)a
  defstruct bound_interval: nil,
            fetcher: %Catchup.Fetcher{},
            memory_monitor: nil,
            task: nil

  @spec child_spec([named_arguments | GenServer.options(), ...]) :: Supervisor.child_spec()
  def child_spec([named_arguments]) when is_map(named_arguments), do: child_spec([named_arguments, []])

  def child_spec([named_arguments, gen_server_options] = start_link_arguments)
      when is_map(named_arguments) and is_list(gen_server_options) do
    # The `child_spec` from `use Supervisor` because the one from `use GenServer` will set the `type` to `:worker`
    # instead of `:supervisor` and use the wrong shutdown timeout
    Supervisor.child_spec(
      %{id: __MODULE__, start: {__MODULE__, :start_link, start_link_arguments}, type: :supervisor},
      []
    )
  end

  @doc """
  Starts supervisor of `Indexer.BlockerFetcher.Catchup` and `Indexer.BlockFetcher.Realtime`.

  For `named_arguments` see `Indexer.BlockFetcher.new/1`.  For `t:GenServer.options/0` see `GenServer.start_link/3`.
  """
  @spec start_link(named_arguments :: map()) :: {:ok, pid}
  @spec start_link(named_arguments :: %{}, GenServer.options()) :: {:ok, pid}
  def start_link(named_arguments, gen_server_options \\ [])
      when is_map(named_arguments) and is_list(gen_server_options) do
    GenServer.start_link(__MODULE__, named_arguments, gen_server_options)
  end

  @impl GenServer
  def init(named_arguments) do
    Logger.metadata(fetcher: :block_catchup)

    state = new(named_arguments)

    send(self(), :catchup_index)

    {:ok, state}
  end

  defp new(%{block_fetcher: common_block_fetcher} = named_arguments) do
    block_fetcher = %Block.Fetcher{common_block_fetcher | broadcast: :catchup, callback_module: Catchup.Fetcher}

    block_interval = Map.get(named_arguments, :block_interval, @block_interval)
    minimum_interval = div(block_interval, 2)
    bound_interval = BoundInterval.within(minimum_interval..(minimum_interval * 10))

    %__MODULE__{
      fetcher: %Catchup.Fetcher{block_fetcher: block_fetcher, memory_monitor: Map.get(named_arguments, :memory_monitor)},
      bound_interval: bound_interval
    }
  end

  @impl GenServer
  def handle_call(:count_children, _from, %__MODULE__{task: task} = state) do
    active =
      case task do
        nil -> 0
        %Task{} -> 1
      end

    {:reply, [specs: 1, active: active, supervisors: 0, workers: 1], state}
  end

  def handle_call({:delete_child, :task}, _from, %__MODULE__{task: task} = state) do
    reason =
      case task do
        nil -> :restarting
        %Task{} -> :running
      end

    {:reply, {:error, reason}, state}
  end

  def handle_call({:delete_child, _}, _from, %__MODULE__{} = state) do
    {:reply, {:error, :not_found}, state}
  end

  @task_shutdown_timeout 5_000

  def handle_call({:get_childspec, :task}, _from, %__MODULE__{fetcher: %Catchup.Fetcher{} = catchup} = state) do
    {:reply,
     {:ok,
      %{
        id: :task,
        start: {Catchup.Fetcher, :task, [catchup]},
        restart: :transient,
        shutdown: @task_shutdown_timeout,
        type: :worker,
        modules: [Catchup.Fetcher]
      }}, state}
  end

  def handle_call({:get_childspec, _}, _from, %__MODULE__{} = state) do
    {:reply, {:error, :not_found}, state}
  end

  def handle_call({:restart_child, :task}, _from, %__MODULE__{fetcher: %Catchup.Fetcher{} = catchup, task: nil} = state) do
    %Task{pid: pid} = task = Task.Supervisor.async_nolink(Catchup.TaskSupervisor, Catchup.Fetcher, :task, [catchup])

    {:reply, {:ok, pid}, %__MODULE__{state | task: task}}
  end

  def handle_call({:restart_child, :task}, _from, %__MODULE__{task: %Task{}} = state) do
    {:reply, {:error, :running}, state}
  end

  def handle_call({:restart_child, _}, _from, %__MODULE__{} = state) do
    {:reply, {:error, :not_found}, state}
  end

  def handle_call({:start_child, %{id: :task}}, _from, %__MODULE__{task: nil} = state) do
    {:reply, {:error, :already_present}, state}
  end

  def handle_call({:start_child, %{id: :task}}, _from, %__MODULE__{task: %Task{pid: pid}} = state) do
    {:reply, {:error, :already_present, pid}, state}
  end

  def handle_call({:start_child, {:task, _, _, _, _, _}}, _from, %__MODULE__{task: nil} = state) do
    {:reply, {:error, :already_present}, state}
  end

  def handle_call({:start_child, {:task, _, _, _, _, _}}, _from, %__MODULE__{task: %Task{pid: pid}} = state) do
    {:reply, {:error, :already_present, pid}, state}
  end

  def handle_call({:start_child, _}, _from, %__MODULE__{} = state) do
    {:reply, {:error, :not_supported}, state}
  end

  def handle_call({:terminate_child, :task}, _from, %__MODULE__{task: nil} = state) do
    {:reply, :ok, state}
  end

  def handle_call({:terminate_child, :task}, _from, %__MODULE__{task: %Task{} = task} = state) do
    Task.shutdown(task, @task_shutdown_timeout)

    {:reply, :ok, %__MODULE__{state | task: nil}}
  end

  def handle_call({:terminate_child, _}, _from, %__MODULE__{} = state) do
    {:reply, {:error, :not_found}, state}
  end

  def handle_call(:which_children, _from, %__MODULE__{task: task} = state) do
    child =
      case task do
        nil -> :restarting
        %Task{pid: pid} -> pid
      end

    {:reply, [{:task, child, :worker, [Catchup.Fetcher]}], state}
  end

  @impl GenServer
  def handle_info(:catchup_index, %__MODULE__{fetcher: %Catchup.Fetcher{} = catchup} = state) do
    {:noreply,
     %__MODULE__{state | task: Task.Supervisor.async_nolink(Catchup.TaskSupervisor, Catchup.Fetcher, :task, [catchup])}}
  end

  def handle_info(
        {ref,
         %{
           first_block_number: first_block_number,
           last_block_number: last_block_number,
           missing_block_count: missing_block_count,
           shrunk: false = shrunk
         }},
        %__MODULE__{
          bound_interval: bound_interval,
          task: %Task{ref: ref}
        } = state
      )
      when is_integer(missing_block_count) do
    new_bound_interval =
      case missing_block_count do
        0 ->
          Logger.info("Index already caught up.",
            first_block_number: first_block_number,
            last_block_number: last_block_number,
            missing_block_count: 0,
            shrunk: shrunk
          )

          BoundInterval.increase(bound_interval)

        _ ->
          Logger.info(
            "Index had to catch up.",
            first_block_number: first_block_number,
            last_block_number: last_block_number,
            missing_block_count: missing_block_count,
            shrunk: shrunk
          )

          BoundInterval.decrease(bound_interval)
      end

    Process.demonitor(ref, [:flush])

    interval = new_bound_interval.current

    Logger.info(fn ->
      ["Checking if index needs to catch up in ", to_string(interval), "ms."]
    end)

    Process.send_after(self(), :catchup_index, interval)

    {:noreply, %__MODULE__{state | bound_interval: new_bound_interval, task: nil}}
  end

  def handle_info(
        {ref,
         %{
           first_block_number: first_block_number,
           missing_block_count: missing_block_count,
           last_block_number: last_block_number,
           shrunk: true = shrunk
         }},
        %__MODULE__{
          task: %Task{ref: ref}
        } = state
      )
      when is_integer(missing_block_count) do
    Process.demonitor(ref, [:flush])

    Logger.info(
      "Index had to catch up, but the sequence was shrunk to save memory, so retrying immediately.",
      first_block_number: first_block_number,
      last_block_number: last_block_number,
      missing_block_count: missing_block_count,
      shrunk: shrunk
    )

    send(self(), :catchup_index)

    {:noreply, %__MODULE__{state | task: nil}}
  end

  def handle_info(
        {:DOWN, ref, :process, pid, reason},
        %__MODULE__{task: %Task{pid: pid, ref: ref}} = state
      ) do
    Logger.error(fn -> "Catchup index stream exited with reason (#{inspect(reason)}). Restarting" end)

    send(self(), :catchup_index)

    {:noreply, %__MODULE__{state | task: nil}}
  end
end
