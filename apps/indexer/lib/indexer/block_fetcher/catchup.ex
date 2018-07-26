defmodule Indexer.BlockFetcher.Catchup do
  @moduledoc """
  Fetches and indexes block ranges from the block before the latest block to genesis (0) that are missing.
  """

  require Logger

  import Indexer, only: [debug: 1]
  import Indexer.BlockFetcher, only: [stream_import: 4]

  alias Explorer.Chain
  alias Indexer.{BlockFetcher, BoundInterval, Sequence}

  @doc """
  Starts `task/1` and puts it in `t:Indexer.BlockFetcher.t/0`
  """
  @spec put(%BlockFetcher{catchup_task: nil}) :: %BlockFetcher{catchup_task: Task.t()}
  def put(%BlockFetcher{catchup_task: nil} = state) do
    catchup_task = Task.Supervisor.async_nolink(Indexer.TaskSupervisor, __MODULE__, :task, [state])

    %BlockFetcher{state | catchup_task: catchup_task}
  end

  def task(%BlockFetcher{json_rpc_named_arguments: json_rpc_named_arguments} = state) do
    {:ok, latest_block_number} = EthereumJSONRPC.fetch_block_number_by_tag("latest", json_rpc_named_arguments)

    case latest_block_number do
      # let realtime indexer get the genesis block
      0 ->
        0

      _ ->
        # realtime indexer gets the current latest block
        first = latest_block_number - 1
        last = 0
        missing_ranges = Chain.missing_block_number_ranges(first..last)
        range_count = Enum.count(missing_ranges)

        missing_block_count =
          missing_ranges
          |> Stream.map(&Enum.count/1)
          |> Enum.sum()

        debug(fn -> "#{missing_block_count} missed blocks in #{range_count} ranges between #{first} and #{last}" end)

        case missing_block_count do
          0 ->
            :ok

          _ ->
            {:ok, seq} = Sequence.start_link(ranges: missing_ranges, step: -1 * state.blocks_batch_size)
            Sequence.cap(seq)

            stream_import(state, seq, :catchup_index, max_concurrency: state.blocks_concurrency)
        end

        missing_block_count
    end
  end

  def handle_success(
        {ref, missing_block_count},
        %BlockFetcher{
          catchup_block_number: catchup_block_number,
          catchup_bound_interval: catchup_bound_interval,
          catchup_task: %Task{ref: ref}
        } = state
      )
      when is_integer(missing_block_count) do
    new_catchup_bound_interval =
      case missing_block_count do
        0 ->
          Logger.info("Index already caught up in #{catchup_block_number}-0")

          BoundInterval.increase(catchup_bound_interval)

        _ ->
          Logger.info("Index had to catch up #{missing_block_count} blocks in #{catchup_block_number}-0")

          BoundInterval.decrease(catchup_bound_interval)
      end

    Process.demonitor(ref, [:flush])

    interval = new_catchup_bound_interval.current

    Logger.info(fn ->
      "Checking if index needs to catch up in #{interval}ms"
    end)

    Process.send_after(self(), :catchup_index, interval)

    %BlockFetcher{state | catchup_bound_interval: new_catchup_bound_interval, catchup_task: nil}
  end

  def handle_failure(
        {:DOWN, ref, :process, pid, reason},
        %BlockFetcher{catchup_task: %Task{pid: pid, ref: ref}} = state
      ) do
    Logger.error(fn -> "Catchup index stream exited with reason (#{inspect(reason)}). Restarting" end)

    send(self(), :catchup_index)

    %BlockFetcher{state | catchup_task: nil}
  end
end
