defmodule Explorer.Chain.Cache.GasUsage do
  @moduledoc """
  Cache for total gas usage.
  """

  require Logger

  @default_cache_period :timer.minutes(30)

  use Explorer.Chain.MapCache,
    name: :gas_usage,
    key: :sum,
    key: :async_task,
    global_ttl: cache_period(),
    ttl_check_interval: :timer.minutes(1),
    callback: &async_task_on_deletion(&1)

  alias Explorer.Chain

  defp handle_fallback(:sum) do
    # This will get the task PID if one exists and launch a new task if not
    # See next `handle_fallback` definition
    get_async_task()

    {:return, nil}
  end

  defp handle_fallback(:async_task) do
    # If this gets called it means an async task was requested, but none exists
    # so a new one needs to be launched
    {:ok, task} =
      Task.start(fn ->
        try do
          result = Chain.fetch_sum_gas_used()

          set_sum(result)
        rescue
          e ->
            Logger.debug([
              "Coudn't update gas used sum test #{inspect(e)}"
            ])
        end

        set_async_task(nil)
      end)

    {:update, task}
  end

  # By setting this as a `callback` an async task will be started each time the
  # `sum` expires (unless there is one already running)
  defp async_task_on_deletion({:delete, _, :sum}), do: get_async_task()

  defp async_task_on_deletion(_data), do: nil

  defp cache_period do
    "TOTAL_GAS_USAGE_CACHE_PERIOD"
    |> System.get_env("")
    |> Integer.parse()
    |> case do
      {integer, ""} -> :timer.seconds(integer)
      _ -> @default_cache_period
    end
  end
end
