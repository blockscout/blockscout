defmodule Explorer.Chain.Cache.TransactionCount do
  @moduledoc """
  Cache for estimated transaction count.
  """

  @default_cache_period :timer.hours(2)

  use Explorer.Chain.MapCache,
    name: :transaction_count,
    key: :count,
    key: :async_task,
    global_ttl: cache_period(),
    ttl_check_interval: :timer.minutes(10),
    callback: &async_task_on_deletion(&1)

  require Logger

  alias Explorer.Chain.Transaction
  alias Explorer.Repo

  defp handle_fallback(:count) do
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
          result = Repo.aggregate(Transaction, :count, :hash, timeout: :infinity)

          set_count(result)
        rescue
          e ->
            Logger.debug([
              "Coudn't update transaction count test #{inspect(e)}"
            ])
        end

        set_async_task(nil)
      end)

    {:update, task}
  end

  # By setting this as a `callback` an async task will be started each time the
  # `count` expires (unless there is one already running)
  defp async_task_on_deletion({:delete, _, :count}), do: get_async_task()

  defp async_task_on_deletion(_data), do: nil

  defp cache_period do
    "TXS_COUNT_CACHE_PERIOD"
    |> System.get_env("")
    |> Integer.parse()
    |> case do
      {integer, ""} -> :timer.seconds(integer)
      _ -> @default_cache_period
    end
  end
end
