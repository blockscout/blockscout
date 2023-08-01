defmodule Explorer.Chain.Cache.GasPriceOracle do
  @moduledoc """
  Cache for gas price oracle (safelow/average/fast gas prices).
  """

  require Logger

  import Ecto.Query,
    only: [
      from: 2
    ]

  alias EthereumJSONRPC.Blocks

  alias Explorer.Chain.{
    Block,
    Wei
  }

  alias Explorer.Repo

  use Explorer.Chain.MapCache,
    name: :gas_price,
    key: :gas_prices,
    key: :async_task,
    global_ttl: Application.get_env(:explorer, __MODULE__)[:global_ttl],
    ttl_check_interval: :timer.seconds(1),
    callback: &async_task_on_deletion(&1)

  @doc """
  Get `safelow`, `average` and `fast` percentile of transactions gas prices among the last `num_of_blocks` blocks
  """
  @spec get_average_gas_price(pos_integer(), pos_integer(), pos_integer(), pos_integer()) ::
          {:error, any} | {:ok, %{String.t() => nil | float, String.t() => nil | float, String.t() => nil | float}}
  def get_average_gas_price(num_of_blocks, safelow_percentile, average_percentile, fast_percentile) do
    safelow_percentile_fraction = safelow_percentile / 100
    average_percentile_fraction = average_percentile / 100
    fast_percentile_fraction = fast_percentile / 100

    fee_query =
      from(
        block in Block,
        left_join: transaction in assoc(block, :transactions),
        where: block.consensus == true,
        where: transaction.status == ^1,
        where: transaction.gas_price > ^0,
        group_by: block.number,
        order_by: [desc: block.number],
        select: %{
          slow_gas_price:
            fragment(
              "percentile_disc(?) within group ( order by ? )",
              ^safelow_percentile_fraction,
              transaction.gas_price
            ),
          average_gas_price:
            fragment(
              "percentile_disc(?) within group ( order by ? )",
              ^average_percentile_fraction,
              transaction.gas_price
            ),
          fast_gas_price:
            fragment(
              "percentile_disc(?) within group ( order by ? )",
              ^fast_percentile_fraction,
              transaction.gas_price
            ),
          slow:
            fragment(
              "percentile_disc(?) within group ( order by ? )",
              ^safelow_percentile_fraction,
              transaction.max_priority_fee_per_gas
            ),
          average:
            fragment(
              "percentile_disc(?) within group ( order by ? )",
              ^average_percentile_fraction,
              transaction.max_priority_fee_per_gas
            ),
          fast:
            fragment(
              "percentile_disc(?) within group ( order by ? )",
              ^fast_percentile_fraction,
              transaction.max_priority_fee_per_gas
            )
        },
        limit: ^num_of_blocks
      )

    gas_prices = fee_query |> Repo.all(timeout: :infinity) |> process_fee_data_from_db()

    {:ok, gas_prices}
  catch
    error ->
      {:error, error}
  end

  defp process_fee_data_from_db([]) do
    %{
      "slow" => nil,
      "average" => nil,
      "fast" => nil
    }
  end

  defp process_fee_data_from_db(fees) do
    fees_length = Enum.count(fees)

    %{
      slow_gas_price: slow_gas_price,
      average_gas_price: average_gas_price,
      fast_gas_price: fast_gas_price,
      slow: slow,
      average: average,
      fast: fast
    } =
      fees
      |> Enum.reduce(
        &Map.merge(&1, &2, fn
          _, v1, v2 when nil not in [v1, v2] -> Decimal.add(v1, v2)
          _, v1, v2 -> v1 || v2
        end)
      )
      |> Map.new(fn
        {key, nil} -> {key, nil}
        {key, value} -> {key, Decimal.div(value, fees_length)}
      end)

    json_rpc_named_arguments = Application.get_env(:explorer, :json_rpc_named_arguments)

    {slow_fee, average_fee, fast_fee} =
      case {nil not in [slow, average, fast], EthereumJSONRPC.fetch_block_by_tag("pending", json_rpc_named_arguments)} do
        {true, {:ok, %Blocks{blocks_params: [%{base_fee_per_gas: base_fee}]}}} when not is_nil(base_fee) ->
          base_fee_wei = base_fee |> Decimal.new() |> Wei.from(:wei)

          {
            priority_with_base_fee(slow, base_fee_wei),
            priority_with_base_fee(average, base_fee_wei),
            priority_with_base_fee(fast, base_fee_wei)
          }

        _ ->
          {gas_price(slow_gas_price), gas_price(average_gas_price), gas_price(fast_gas_price)}
      end

    %{
      "slow" => slow_fee,
      "average" => average_fee,
      "fast" => fast_fee
    }
  end

  defp priority_with_base_fee(priority, base_fee) do
    priority |> Wei.from(:wei) |> Wei.sum(base_fee) |> Wei.to(:gwei) |> Decimal.to_float() |> Float.ceil(2)
  end

  defp gas_price(value) do
    value |> Wei.from(:wei) |> Wei.to(:gwei) |> Decimal.to_float() |> Float.ceil(2)
  end

  defp num_of_blocks, do: Application.get_env(:explorer, __MODULE__)[:num_of_blocks]

  defp safelow, do: Application.get_env(:explorer, __MODULE__)[:safelow_percentile]

  defp average, do: Application.get_env(:explorer, __MODULE__)[:average_percentile]

  defp fast, do: Application.get_env(:explorer, __MODULE__)[:fast_percentile]

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
          result = get_average_gas_price(num_of_blocks(), safelow(), average(), fast())

          set_all(result)
        rescue
          e ->
            Logger.debug([
              "Couldn't update gas used gas_prices",
              Exception.format(:error, e, __STACKTRACE__)
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
end
