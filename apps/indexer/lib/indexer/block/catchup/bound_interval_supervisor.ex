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

  @max_missing_block_count 100

  @enforce_keys ~w(bound_interval fetcher max_missing_block_count)a
  defstruct bound_interval: nil,
            fetcher: %Catchup.Fetcher{},
            max_missing_block_count: @max_missing_block_count,
            memory_monitor: nil,
            task: nil,
            task_args: nil

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

    state = %__MODULE__{max_missing_block_count: max_missing_block_count} = new(named_arguments)

    {:ok, state, {:continue, {:catchup_index, [max_missing_block_count]}}}
  end

  defp new(%{block_fetcher: common_block_fetcher} = named_arguments) do
    block_fetcher = %Block.Fetcher{common_block_fetcher | broadcast: :catchup, callback_module: Catchup.Fetcher}

    block_interval = Map.get(named_arguments, :block_interval, @block_interval)
    minimum_interval = div(block_interval, 2)
    bound_interval = BoundInterval.within(minimum_interval..(minimum_interval * 10))

    %__MODULE__{
      fetcher: %Catchup.Fetcher{block_fetcher: block_fetcher, memory_monitor: Map.get(named_arguments, :memory_monitor)},
      bound_interval: bound_interval,
      max_missing_block_count: Map.get(named_arguments, :max_missing_block_count, @max_missing_block_count)
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

  def handle_call(
        {:get_childspec, :task},
        _from,
        %__MODULE__{fetcher: %Catchup.Fetcher{} = catchup, max_missing_block_count: max_missing_block_count} = state
      ) do
    {:reply,
     {:ok,
      %{
        id: :task,
        start: {Catchup.Fetcher, :task, [catchup, max_missing_block_count]},
        restart: :transient,
        shutdown: @task_shutdown_timeout,
        type: :worker,
        modules: [Catchup.Fetcher]
      }}, state}
  end

  def handle_call({:get_childspec, _}, _from, %__MODULE__{} = state) do
    {:reply, {:error, :not_found}, state}
  end

  def handle_call(
        {:restart_child, :task},
        _from,
        %__MODULE__{fetcher: %Catchup.Fetcher{} = catchup, max_missing_block_count: max_missing_block_count, task: nil} =
          state
      ) do
    %Task{pid: pid} =
      task =
      Task.Supervisor.async_nolink(Catchup.TaskSupervisor, Catchup.Fetcher, :task, [catchup, max_missing_block_count])

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
  def handle_continue({:catchup_index, task_args}, state) do
    handle_catchup(task_args, state)
  end

  @impl GenServer
  def handle_info({:catchup_index, task_args}, state) do
    handle_catchup(task_args, state)
  end

  def handle_info(
        {ref,
         %{
           missing_block_number_search_range: first_block_number..last_block_number,
           missing_block_count: missing_block_count,
           shrunk: shrunk
         }},
        %__MODULE__{max_missing_block_count: max_missing_block_count, task: %Task{ref: ref}} = state
      )
      when is_integer(missing_block_count) and missing_block_count >= 0 and shrunk in [false, true] do
    Process.demonitor(ref, [:flush])

    delay = delay(last_block_number, shrunk, state)
    new_first_block_number = new_first_block_number(last_block_number)

    Logger.info(
      fn ->
        [
          caught_up_iodata(missing_block_count),
          ?\s,
          range_iodata(last_block_number),
          shrunk_iodata(shrunk, missing_block_count),
          ".  ",
          checking_iodata(delay, new_first_block_number)
        ]
      end,
      first_block_number: first_block_number,
      last_block_number: last_block_number,
      missing_block_count: missing_block_count,
      shrunk: shrunk
    )

    new_state = update_bound_interval(%__MODULE__{state | task: nil, task_args: nil}, missing_block_count, shrunk)
    message = catchup_index_message(new_first_block_number, max_missing_block_count)

    case delay do
      0 ->
        {:noreply, new_state, {:continue, message}}

      _ ->
        Process.send_after(self(), message, delay)
        {:noreply, new_state}
    end
  end

  def handle_info(
        {:DOWN, ref, :process, pid, reason},
        %__MODULE__{task: %Task{pid: pid, ref: ref}, task_args: task_args} = state
      )
      when is_list(task_args) do
    Logger.error(fn -> "Task exited with reason (#{inspect(reason)}). Restarting" end)

    {:noreply, %__MODULE__{state | task: nil, task_args: nil}, {:continue, {:catchup_index, task_args}}}
  end

  defp handle_catchup(task_args, %__MODULE__{fetcher: %Catchup.Fetcher{} = catchup} = state) when is_list(task_args) do
    {:noreply,
     %__MODULE__{
       state
       | task:
           Task.Supervisor.async_nolink(
             Catchup.TaskSupervisor,
             Catchup.Fetcher,
             :task,
             [
               catchup
               | task_args
             ]
           ),
         task_args: task_args
     }}
  end

  defp update_bound_interval(state, missing_block_count, shrunk)

  defp update_bound_interval(state, 0, false) do
    update_in(state.bound_interval, &BoundInterval.increase/1)
  end

  defp update_bound_interval(state, 0, true), do: state

  defp update_bound_interval(state, _, _) do
    update_in(state.bound_interval, &BoundInterval.decrease/1)
  end

  defp delay(last_block_number, shrunk, state)
  defp delay(0, false, %__MODULE__{bound_interval: %BoundInterval{current: interval}}), do: interval
  defp delay(0, true, _), do: 0
  defp delay(last_block_number, _, _) when is_integer(last_block_number), do: 0

  defp new_first_block_number(0), do: :latest

  defp new_first_block_number(last_block_number) when is_integer(last_block_number) and last_block_number > 0,
    do: last_block_number - 1

  defp caught_up_iodata(0), do: "Already caught up"

  defp caught_up_iodata(missing_block_count) when is_integer(missing_block_count) and missing_block_count > 0,
    do: "Had to catch up"

  defp range_iodata(0), do: "entire history"

  defp range_iodata(last_block_number) when is_integer(last_block_number) and last_block_number > 0,
    do: "in search range"

  defp checking_iodata(delay, from) do
    ["Checking for missing blocks ", delay_iodata(delay), ?\s, from_iodata(from)]
  end

  defp delay_iodata(0), do: "immediately"

  defp delay_iodata(milliseconds) when is_integer(milliseconds) and milliseconds > 0 do
    ["in ", to_string(milliseconds), "ms"]
  end

  defp from_iodata(:latest), do: "latest"

  defp from_iodata(first_block_number) when is_integer(first_block_number) and first_block_number >= 0 do
    ["before ", to_string(first_block_number)]
  end

  defp shrunk_iodata(false, _), do: []
  defp shrunk_iodata(true, 0), do: ", but after shrinking"
  defp shrunk_iodata(true, _), do: " and after shrinking"

  defp catchup_index_message(new_first_block_number, max_missing_block_count) do
    task_args =
      case new_first_block_number do
        :latest -> [max_missing_block_count]
        _ -> [new_first_block_number, max_missing_block_count]
      end

    {:catchup_index, task_args}
  end
end
