defmodule Explorer.Chain.Cache.GasPriceOracle do
  @moduledoc """
  Cache for gas price oracle (safelow/average/fast gas prices).
  """

  require Logger

  @default_cache_period :timer.minutes(10)

  @num_of_blocks (if System.get_env("GAS_PRICE_ORACLE_NUM_OF_BLOCKS") do
                    case Integer.parse(System.get_env("GAS_PRICE_ORACLE_NUM_OF_BLOCKS")) do
                      {integer, ""} -> integer
                      _ -> 200
                    end
                  end)

  @safelow (if System.get_env("GAS_PRICE_ORACLE_SAFELOW_PERCENTILE") do
              case Integer.parse(System.get_env("GAS_PRICE_ORACLE_SAFELOW_PERCENTILE")) do
                {integer, ""} -> integer
                _ -> 35
              end
            end)

  @average (if System.get_env("GAS_PRICE_ORACLE_AVERAGE_PERCENTILE") do
              case Integer.parse(System.get_env("GAS_PRICE_ORACLE_AVERAGE_PERCENTILE")) do
                {integer, ""} -> integer
                _ -> 60
              end
            end)

  @fast (if System.get_env("GAS_PRICE_ORACLE_FAST_PERCENTILE") do
           case Integer.parse(System.get_env("GAS_PRICE_ORACLE_FAST_PERCENTILE")) do
             {integer, ""} -> integer
             _ -> 90
           end
         end)

  use Explorer.Chain.MapCache,
    name: :gas_price,
    key: :gas_prices,
    key: :async_task,
    global_ttl: cache_period(),
    ttl_check_interval: :timer.minutes(5),
    callback: &async_task_on_deletion(&1)

  alias Explorer.Chain

  defp handle_fallback(:gas_prices) do
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
          result = Chain.get_average_gas_price(@num_of_blocks, @safelow, @average, @fast)

          set_all(result)
        rescue
          e ->
            Logger.debug([
              "Coudn't update gas used gas_prices #{inspect(e)}"
            ])
        end

        set_async_task(nil)
      end)

    {:update, task}
  end

  # By setting this as a `callback` an async task will be started each time the
  # `gas_prices` expires (unless there is one already running)
  defp async_task_on_deletion({:delete, _, :gas_prices}), do: get_async_task()

  defp async_task_on_deletion(_data), do: nil

  defp cache_period do
    "GAS_PRICE_ORACLE_CACHE_PERIOD"
    |> System.get_env("")
    |> Integer.parse()
    |> case do
      {integer, ""} -> :timer.seconds(integer)
      _ -> @default_cache_period
    end
  end
end
