defmodule Explorer.Chain.Cache.Counters.GasUsageSum do
  @moduledoc """
  Cache for total gas usage.
  """
  require Logger

  import Ecto.Query,
    only: [
      from: 2
    ]

  use Explorer.Chain.MapCache,
    name: :gas_usage,
    key: :sum,
    key: :async_task,
    global_ttl: :infinity,
    ttl_check_interval: :timer.seconds(1),
    callback: &async_task_on_deletion(&1)

  alias Explorer.Chain.Cache.Counters.Helper, as: CacheCountersHelper
  alias Explorer.Chain.Cache.Counters.LastFetchedCounter
  alias Explorer.Chain.Transaction
  alias Explorer.Repo

  @cache_key "gas_usage_sum"

  @spec total() :: non_neg_integer()
  def total do
    cached_value_from_ets = __MODULE__.get_sum()

    CacheCountersHelper.evaluate_count(@cache_key, cached_value_from_ets)
  end

  defp handle_fallback(:sum) do
    # This will get the task PID if one exists, check if it's running and launch
    # a new task if task doesn't exist or it's not running.
    # See next `handle_fallback` definition
    safe_get_async_task()

    {:return, nil}
  end

  defp handle_fallback(:async_task) do
    if Application.get_env(:explorer, __MODULE__)[:enabled] do
      # If this gets called it means an async task was requested, but none exists
      # so a new one needs to be launched
      {:ok, task} =
        Task.start_link(fn ->
          try do
            result = fetch_sum_gas_used()

            params = %{
              counter_type: @cache_key,
              value: result
            }

            LastFetchedCounter.upsert(params)

            set_sum(%ConCache.Item{
              ttl: CacheCountersHelper.ttl(__MODULE__, "CACHE_TOTAL_GAS_USAGE_PERIOD"),
              value: result
            })
          rescue
            e ->
              Logger.debug([
                "Couldn't update total gas used: ",
                Exception.format(:error, e, __STACKTRACE__)
              ])
          end

          set_async_task(nil)
        end)

      {:update, task}
    else
      {:update, nil}
    end
  end

  # By setting this as a `callback` an async task will be started each time the
  # `sum` expires (unless there is one already running)
  defp async_task_on_deletion({:delete, _, :sum}), do: safe_get_async_task()

  defp async_task_on_deletion(_data), do: nil

  @spec fetch_sum_gas_used() :: non_neg_integer
  defp fetch_sum_gas_used do
    query =
      from(
        t0 in Transaction,
        select: fragment("SUM(t0.gas_used)")
      )

    Repo.one!(query, timeout: :infinity) || 0
  end
end
