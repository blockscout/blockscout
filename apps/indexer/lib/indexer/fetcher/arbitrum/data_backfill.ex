defmodule Indexer.Fetcher.Arbitrum.DataBackfill do
  @moduledoc """
    Backfill worker for Arbitrum-specific fields in blocks and transactions.
  """
  use Indexer.Fetcher, restart: :transient
  use Spandex.Decorators

  import Indexer.Fetcher.Arbitrum.Utils.Logging, only: [log_warning: 1, log_debug: 1, log_info: 1]

  require Logger

  alias Indexer.BufferedTask
  alias Indexer.Fetcher.Arbitrum.Utils.Db, as: ArbitrumDbUtils
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

    indexer_first_block = Application.get_all_env(:indexer)[:first_block]
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
  def init(initial, reducer, _) do
    time_of_start = DateTime.utc_now()

    log_debug("Waiting for the first block to be indexed")

    reducer.({:wait_for_new_block, time_of_start}, initial)
  end

  @impl BufferedTask
  def run(entries, state)

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
