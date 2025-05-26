defmodule Explorer.Chain.Cache.Counters.PendingTransactionOperationCount do
  @moduledoc """
  Cache for estimated `pending_transaction_operations` count.
  """

  use Explorer.Chain.MapCache,
    name: :pending_transaction_operations_count,
    key: :count,
    key: :async_task,
    global_ttl: Application.get_env(:explorer, __MODULE__)[:global_ttl],
    ttl_check_interval: :timer.seconds(1),
    callback: &async_task_on_deletion(&1)

  require Logger

  alias EthereumJSONRPC.Utility.RangesHelper
  alias Explorer.Chain.Cache.BlockNumber
  alias Explorer.Chain.Cache.Counters.Helper, as: CacheCountersHelper
  alias Explorer.Chain.Cache.Counters.LastFetchedCounter
  alias Explorer.Chain.PendingTransactionOperation

  @cache_key "pending_transaction_operations_count"

  @doc """
  Gets count of `t:Explorer.Chain.PendingTransactionOperation.t/0`.

  """
  @spec get() :: non_neg_integer()
  def get do
    cached_value_from_ets = __MODULE__.get_count()

    CacheCountersHelper.evaluate_count(
      @cache_key,
      cached_value_from_ets,
      :estimated_pending_transaction_operations_count
    )
  end

  defp handle_fallback(:count) do
    # This will get the task PID if one exists, check if it's running and launch
    # a new task if task doesn't exist or it's not running.
    # See next `handle_fallback` definition
    safe_get_async_task()

    {:return, nil}
  end

  defp handle_fallback(:async_task) do
    # If this gets called it means an async task was requested, but none exists
    # so a new one needs to be launched
    {:ok, task} =
      Task.start_link(fn ->
        try do
          min_blockchain_trace_block_number =
            RangesHelper.get_min_block_number_from_range_string(Application.get_env(:indexer, :trace_block_ranges))

          result =
            PendingTransactionOperation.blocks_count_in_range(min_blockchain_trace_block_number, BlockNumber.get_max())

          params = %{
            counter_type: @cache_key,
            value: result
          }

          LastFetchedCounter.upsert(params)

          set_count(%ConCache.Item{ttl: CacheCountersHelper.ttl(__MODULE__, "CACHE_PBO_COUNT_PERIOD"), value: result})
        rescue
          e ->
            Logger.debug([
              "Couldn't update pending_transaction_operations count: ",
              Exception.format(:error, e, __STACKTRACE__)
            ])
        end

        set_async_task(nil)
      end)

    {:update, task}
  end

  # By setting this as a `callback` an async task will be started each time the
  # `count` expires (unless there is one already running)
  defp async_task_on_deletion({:delete, _, :count}), do: safe_get_async_task()

  defp async_task_on_deletion(_data), do: nil
end
