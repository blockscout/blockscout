defmodule Explorer.Chain.Cache.GasPriceOracle do
  @moduledoc """
  Cache for gas price oracle (safelow/average/fast gas prices).
  """

  require Logger

  import Ecto.Query,
    only: [
      from: 2
    ]

  alias Explorer.Chain.{
    Block,
    Wei
  }

  alias Explorer.Repo

  @num_of_blocks (case Integer.parse(System.get_env("GAS_PRICE_ORACLE_NUM_OF_BLOCKS", "200")) do
                    {integer, ""} -> integer
                    _ -> 200
                  end)

  @safelow (case Integer.parse(System.get_env("GAS_PRICE_ORACLE_SAFELOW_PERCENTILE", "35")) do
              {integer, ""} -> integer
              _ -> 35
            end)

  @average (case Integer.parse(System.get_env("GAS_PRICE_ORACLE_AVERAGE_PERCENTILE", "60")) do
              {integer, ""} -> integer
              _ -> 60
            end)

  @fast (case Integer.parse(System.get_env("GAS_PRICE_ORACLE_FAST_PERCENTILE", "90")) do
           {integer, ""} -> integer
           _ -> 90
         end)

  use Explorer.Chain.MapCache,
    name: :gas_price,
    key: :gas_prices,
    key: :async_task,
    global_ttl: Application.get_env(:explorer, __MODULE__)[:global_ttl],
    ttl_check_interval: :timer.seconds(1),
    callback: &async_task_on_deletion(&1)

  def get_average_gas_price(num_of_blocks, safelow_percentile, average_percentile, fast_percentile) do
    lates_gas_price_query =
      from(
        block in Block,
        left_join: transaction in assoc(block, :transactions),
        where: block.consensus == true,
        where: transaction.status == ^1,
        where: transaction.gas_price > ^0,
        group_by: block.number,
        order_by: [desc: block.number],
        select: min(transaction.gas_price),
        limit: ^num_of_blocks
      )

    latest_gas_prices =
      lates_gas_price_query
      |> Repo.all(timeout: :infinity)

    latest_ordered_gas_prices =
      latest_gas_prices
      |> Enum.map(fn %Wei{value: gas_price} -> Decimal.to_integer(gas_price) end)

    safelow_gas_price = gas_price_percentile_to_gwei(latest_ordered_gas_prices, safelow_percentile)
    average_gas_price = gas_price_percentile_to_gwei(latest_ordered_gas_prices, average_percentile)
    fast_gas_price = gas_price_percentile_to_gwei(latest_ordered_gas_prices, fast_percentile)

    gas_prices = %{
      "slow" => safelow_gas_price,
      "average" => average_gas_price,
      "fast" => fast_gas_price
    }

    {:ok, gas_prices}
  catch
    error ->
      {:error, error}
  end

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
          result = get_average_gas_price(@num_of_blocks, @safelow, @average, @fast)

          set_all(result)
        rescue
          e ->
            Logger.debug([
              "Coudn't update gas used gas_prices",
              Exception.format(:error, e, __STACKTRACE__)
            ])
        end

        set_async_task(nil)
      end)

    {:update, task}
  end

  defp gas_price_percentile_to_gwei(gas_prices, percentile) do
    gas_price_wei = percentile(gas_prices, percentile)

    if gas_price_wei do
      gas_price_gwei = Wei.to(%Wei{value: Decimal.from_float(gas_price_wei)}, :gwei)

      gas_price_gwei_float = gas_price_gwei |> Decimal.to_float()

      if gas_price_gwei_float > 0.01 do
        gas_price_gwei_float
        |> Float.ceil(2)
      else
        gas_price_gwei_float
      end
    else
      nil
    end
  end

  @spec percentile(list, number) :: number | nil
  defp percentile([], _), do: nil
  defp percentile([x], _), do: x
  defp percentile(list, 0), do: Enum.min(list)
  defp percentile(list, 100), do: Enum.max(list)

  defp percentile(list, n) when is_list(list) and is_number(n) do
    s = Enum.sort(list)
    r = n / 100.0 * (length(list) - 1)
    f = :erlang.trunc(r)
    lower = Enum.at(s, f)
    upper = Enum.at(s, f + 1)
    lower + (upper - lower) * (r - f)
  end

  # By setting this as a `callback` an async task will be started each time the
  # `gas_prices` expires (unless there is one already running)
  defp async_task_on_deletion({:delete, _, :gas_prices}), do: get_async_task()

  defp async_task_on_deletion(_data), do: nil
end
