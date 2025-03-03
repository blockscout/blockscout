defmodule Indexer.Fetcher.Arbitrum.DataBackfill do
  @moduledoc """
    Manages the backfilling process for Arbitrum-specific block data in a controlled manner
    using BufferedTask functionality.

    This fetcher processes historical blocks in reverse chronological order, starting from
    the most recently indexed block and working backwards towards the first rollup block.
    It coordinates with the `Indexer.Fetcher.Arbitrum.Workers.Backfill` module to discover
    and backfill missing Arbitrum L2-specific information.

    The fetcher leverages BufferedTask to break down the entire block range into smaller,
    manageable tasks. Each task processes a specific block range, and BufferedTask handles:
    - Scheduling the next block range for processing
    - Managing task retries when issues with JSON RPC or DB are encountered or when
      the blocks are not yet indexed

    The fetcher implements two main operational modes:
    - Initial waiting for the first indexed block
    - Continuous backfilling of historical blocks in configurable depth ranges

    After identifying the first indexed block, backfill tasks are represented as tuples
    containing a timeout and an end block number `{timeout, end_block}`. The timeout
    mechanism serves two purposes:
    - Under normal conditions, the timeout immediately expires, allowing immediate
      processing of the block range
    - When blocks are missing from the database, the timeout is set to a future time
      (configured by `:recheck_interval`) to allow the catch-up block fetcher time to
      index the missing blocks before retrying

    After reaching the first rollup block, the fetcher is stopped.
  """

  use Indexer.Fetcher, restart: :transient
  use Spandex.Decorators

  import Indexer.Fetcher.Arbitrum.Utils.Logging, only: [log_warning: 1, log_debug: 1, log_info: 1]

  require Logger

  alias EthereumJSONRPC.Utility.RangesHelper
  alias Indexer.BufferedTask
  alias Indexer.Fetcher.Arbitrum.Utils.Db.Common, as: ArbitrumDbUtils
  alias Indexer.Fetcher.Arbitrum.Workers.Backfill

  @behaviour BufferedTask

  # Will do one block range at a time
  @default_max_batch_size 1
  @default_max_concurrency 1

  # the flush interval is small enough to pickup the next block range or retry
  # the same block range without with low latency. In case if retry must happen
  # due to unindexed blocks discovery, run callback will have its own timer
  # management to make sure that the same unindexed block range is not tried to
  # be processed multiple times during short period of time
  @flush_interval :timer.seconds(2)

  def child_spec([init_options, gen_server_options]) do
    {json_rpc_named_arguments, mergeable_init_options} = Keyword.pop(init_options, :json_rpc_named_arguments)

    unless json_rpc_named_arguments do
      raise ArgumentError,
            ":json_rpc_named_arguments must be provided to `#{__MODULE__}.child_spec` " <>
              "to allow for json_rpc calls when running."
    end

    indexer_first_block =
      RangesHelper.get_min_block_number_from_range_string(Application.get_env(:indexer, :block_ranges))

    rollup_chunk_size = Application.get_all_env(:indexer)[Indexer.Fetcher.Arbitrum][:rollup_chunk_size]
    backfill_blocks_depth = Application.get_all_env(:indexer)[__MODULE__][:backfill_blocks_depth]
    recheck_interval = Application.get_all_env(:indexer)[__MODULE__][:recheck_interval]

    buffered_task_init_options =
      defaults()
      |> Keyword.merge(mergeable_init_options)
      |> Keyword.merge(
        state: %{
          config: %{
            rollup_rpc: %{
              json_rpc_named_arguments: json_rpc_named_arguments,
              chunk_size: rollup_chunk_size,
              first_block: indexer_first_block
            },
            backfill_blocks_depth: backfill_blocks_depth,
            recheck_interval: recheck_interval
          }
        }
      )

    Supervisor.child_spec({BufferedTask, [{__MODULE__, buffered_task_init_options}, gen_server_options]},
      id: __MODULE__,
      # This allows the buffered task-based process to stop, otherwise
      # the supervisor would restart it
      restart: :transient
    )
  end

  @impl BufferedTask
  @spec init({0, []}, function(), map()) :: {non_neg_integer(), list()}
  def init(initial, reducer, _) do
    time_of_start = DateTime.utc_now()

    log_debug("Waiting for the first block to be indexed")

    reducer.({:wait_for_new_block, time_of_start}, initial)
  end

  @impl BufferedTask
  @spec run([{:wait_for_new_block, DateTime.t()} | {:backfill, {non_neg_integer(), non_neg_integer()}}], map()) ::
          :ok | :retry | {:retry, [{:backfill, {non_neg_integer(), non_neg_integer()}}]}
  def run(entries, state)

  # Waits for the next block to be indexed and schedules the next backfill task
  # with the block preceding the last indexed block as the end of the block range
  # for backfill.
  def run([{:wait_for_new_block, time_of_start}], _) do
    case ArbitrumDbUtils.closest_block_after_timestamp(time_of_start) do
      {:ok, block} ->
        log_debug("Scheduling next backfill up to #{block - 1}")
        BufferedTask.buffer(__MODULE__, [{:backfill, {0, block - 1}}], false)
        :ok

      {:error, _} ->
        log_warning("No progress of the block fetcher found")
        :retry
    end
  end

  # Accepts a backfill task as as a tuple with the timeout and the end block of next
  # batch of blocks to be backfilled.
  # Then:
  # - Checks if the backfill task has timed out and discovers the blocks to be backfilled.
  # - If the blocks are discovered successfully, schedules the next backfill task with
  #   the block preceding the last discovered block as the end of the block range for
  #   backfill.
  # - If the batch of blocks was not handled properly due to JSON RPC or DB related
  #   issues, retries the same backfill task.
  # - If the blocks cannot be discovered due to the lack of indexed blocks, schedules
  #   the next backfill task with the increased timeout.
  def run([{:backfill, {timeout, end_block}}], state) do
    now = DateTime.to_unix(DateTime.utc_now(), :millisecond)

    if timeout > now do
      :retry
    else
      case Backfill.discover_blocks(end_block, state) do
        {:ok, start_block} ->
          schedule_next_or_stop(start_block - 1, state.config.rollup_rpc.first_block)

        {:error, :discover_blocks_error} ->
          :retry

        {:error, :not_indexed_blocks} ->
          {:retry, [{:backfill, {now + state.config.recheck_interval, end_block}}]}
      end
    end
  end

  def run(entries, _) do
    log_warning("Unexpected entry in buffer: #{inspect(entries)}")
    :retry
  end

  # Schedules the next backfill task or stops the process when reaching the first rollup block.
  #
  # ## Parameters
  # - `next_end_block`: The block number where the next block range for backfill
  #   should end
  # - `rollup_first_block`: The first block number in the rollup
  #
  # ## Returns
  # - `:ok` in all cases
  @spec schedule_next_or_stop(non_neg_integer(), non_neg_integer()) :: :ok
  defp schedule_next_or_stop(next_end_block, rollup_first_block) do
    if next_end_block >= rollup_first_block do
      log_debug("Scheduling next backfill up to #{next_end_block}")
      BufferedTask.buffer(__MODULE__, [{:backfill, {0, next_end_block}}], false)
      :ok
    else
      log_info("The first block achieved, stopping backfill")
      GenServer.stop(__MODULE__, :shutdown)
      :ok
    end
  end

  defp defaults do
    [
      flush_interval: @flush_interval,
      max_concurrency: @default_max_concurrency,
      max_batch_size: @default_max_batch_size,
      poll: false,
      task_supervisor: __MODULE__.TaskSupervisor,
      metadata: [fetcher: :arbitrum_backfill]
    ]
  end
end
