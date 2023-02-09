defmodule Explorer.Chain.Cache.GasUsage do
  @moduledoc """
  Cache for total gas usage.
  """

  require Logger

  import Ecto.Query,
    only: [
      from: 2
    ]

  @default_cache_period :timer.hours(2)
  config = Application.compile_env(:explorer, __MODULE__)
  @enabled Keyword.get(config, :enabled)

  use Explorer.Chain.MapCache,
    name: :gas_usage,
    key: :sum,
    key: :async_task,
    global_ttl: cache_period(),
    ttl_check_interval: :timer.minutes(15),
    callback: &async_task_on_deletion(&1)

  alias Explorer.Chain.Transaction
  alias Explorer.Repo

  @spec total() :: non_neg_integer()
  def total do
    cached_value = __MODULE__.get_sum()

    if is_nil(cached_value) do
      0
    else
      cached_value
    end
  end

  defp handle_fallback(:sum) do
    # This will get the task PID if one exists and launch a new task if not
    # See next `handle_fallback` definition
    get_async_task()

    {:return, nil}
  end

  defp handle_fallback(:async_task) do
    if @enabled do
      # If this gets called it means an async task was requested, but none exists
      # so a new one needs to be launched
      {:ok, task} =
        Task.start(fn ->
          try do
            result = fetch_sum_gas_used()

            set_sum(result)
          rescue
            e ->
              Logger.debug([
                "Coudn't update gas used sum: ",
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
  defp async_task_on_deletion({:delete, _, :sum}), do: get_async_task()

  defp async_task_on_deletion(_data), do: nil

  defp cache_period do
    "CACHE_TOTAL_GAS_USAGE_PERIOD"
    |> System.get_env("")
    |> Integer.parse()
    |> case do
      {integer, ""} -> :timer.seconds(integer)
      _ -> @default_cache_period
    end
  end

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
