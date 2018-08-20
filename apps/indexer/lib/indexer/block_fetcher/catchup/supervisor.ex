defmodule Indexer.BlockFetcher.Catchup.Supervisor do
  @moduledoc """
  Supervises the `Indexer.BlockerFetcher.Catchup` with exponential backoff for restarts.
  """

  # NOT a `Supervisor` because of the `Task` restart strategies are custom.
  use GenServer

  require Logger

  alias Indexer.{BlockFetcher, BoundInterval}
  alias Indexer.BlockFetcher.Catchup

  # milliseconds
  @block_interval 5_000

  @enforce_keys ~w(bound_interval catchup)a
  defstruct bound_interval: nil,
            catchup: %Catchup{},
            task: nil

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
  def start_link([named_arguments, gen_server_options]) when is_map(named_arguments) and is_list(gen_server_options) do
    GenServer.start_link(__MODULE__, named_arguments, gen_server_options)
  end

  @impl GenServer
  def init(named_arguments) do
    state = new(named_arguments)

    send(self(), :catchup_index)

    {:ok, state}
  end

  defp new(%{block_fetcher: common_block_fetcher} = named_arguments) do
    block_fetcher = %BlockFetcher{common_block_fetcher | broadcast: false, callback_module: Catchup}

    block_interval = Map.get(named_arguments, :block_interval, @block_interval)
    minimum_interval = div(block_interval, 2)
    bound_interval = BoundInterval.within(minimum_interval..(minimum_interval * 10))

    %__MODULE__{
      catchup: %Catchup{block_fetcher: block_fetcher},
      bound_interval: bound_interval
    }
  end

  @impl GenServer
  def handle_info(:catchup_index, %__MODULE__{catchup: %Catchup{} = catchup} = state) do
    {:noreply,
     %__MODULE__{state | task: Task.Supervisor.async_nolink(Indexer.TaskSupervisor, Catchup, :task, [catchup])}}
  end

  def handle_info(
        {ref, %{first_block_number: first_block_number, missing_block_count: missing_block_count}},
        %__MODULE__{
          bound_interval: bound_interval,
          task: %Task{ref: ref}
        } = state
      )
      when is_integer(missing_block_count) do
    new_bound_interval =
      case missing_block_count do
        0 ->
          Logger.info("Index already caught up in #{first_block_number}-0")

          BoundInterval.increase(bound_interval)

        _ ->
          Logger.info("Index had to catch up #{missing_block_count} blocks in #{first_block_number}-0")

          BoundInterval.decrease(bound_interval)
      end

    Process.demonitor(ref, [:flush])

    interval = new_bound_interval.current

    Logger.info(fn ->
      "Checking if index needs to catch up in #{interval}ms"
    end)

    Process.send_after(self(), :catchup_index, interval)

    {:noreply, %__MODULE__{state | bound_interval: new_bound_interval, task: nil}}
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
