defmodule Explorer.Chain.Cache.Counters.TransactionsCount do
  @moduledoc """
  Cache for total transactions count.
  """

  use Explorer.Chain.MapCache,
    name: :transaction_count,
    key: :count,
    key: :async_task,
    global_ttl: :infinity,
    ttl_check_interval: :timer.seconds(1),
    callback: &async_task_on_deletion(&1)

  require Logger

  alias Explorer.Chain.Cache.Counters.Helper, as: CacheCountersHelper
  alias Explorer.Chain.Cache.Counters.LastFetchedCounter
  alias Explorer.Chain.Transaction
  alias Explorer.Repo

  @cache_key "transactions_count"

  @doc """
  Gets count of `t:Explorer.Chain.Transaction.t/0`.

  Gets count of both collated and pending transactions using the transactions table statistics.
  """
  @spec get() :: non_neg_integer()
  def get do
    cached_value_from_ets = __MODULE__.get_count()

    CacheCountersHelper.evaluate_count(@cache_key, cached_value_from_ets, :estimated_transactions_count)
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
          result = Repo.aggregate(Transaction, :count, :hash, timeout: :infinity)

          params = %{
            counter_type: @cache_key,
            value: result
          }

          LastFetchedCounter.upsert(params)

          set_count(%ConCache.Item{ttl: CacheCountersHelper.ttl(__MODULE__, "CACHE_TXS_COUNT_PERIOD"), value: result})
        rescue
          e ->
            Logger.debug([
              "Couldn't update transaction count: ",
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
