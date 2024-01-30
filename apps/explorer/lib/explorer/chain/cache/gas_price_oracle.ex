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
    DenormalizationHelper,
    Transaction,
    Wei
  }

  alias Explorer.Counters.AverageBlockTime
  alias Explorer.{Market, Repo}
  alias Timex.Duration

  use Explorer.Chain.MapCache,
    name: :gas_price,
    key: :gas_prices,
    key: :gas_prices_acc,
    key: :updated_at,
    key: :old_gas_prices,
    key: :old_updated_at,
    key: :async_task,
    global_ttl: :infinity,
    ttl_check_interval: :timer.seconds(1),
    callback: &async_task_on_deletion(&1)

  @doc """
  Calculates how much time left till the next gas prices updated taking into account estimated query running time.
  """
  @spec update_in :: non_neg_integer()
  def update_in do
    case {get_old_updated_at(), get_updated_at()} do
      {%DateTime{} = old_updated_at, %DateTime{} = updated_at} ->
        time_to_update = DateTime.diff(updated_at, old_updated_at, :millisecond) + 500
        time_since_last_update = DateTime.diff(DateTime.utc_now(), updated_at, :millisecond)
        next_update_in = time_to_update - time_since_last_update
        if next_update_in <= 0, do: global_ttl(), else: next_update_in

      _ ->
        global_ttl() + :timer.seconds(2)
    end
  end

  @doc """
  Calculates the `slow`, `average`, and `fast` gas price and time percentiles from the last `num_of_blocks` blocks and estimates the fiat price for each percentile.
  These percentiles correspond to the likelihood of a transaction being picked up by miners depending on the fee offered.
  """
  @spec get_average_gas_price(pos_integer(), pos_integer(), pos_integer(), pos_integer()) ::
          {{:error, any} | {:ok, %{slow: gas_price, average: gas_price, fast: gas_price}},
           [
             %{
               block_number: non_neg_integer(),
               slow_gas_price: nil | Decimal.t(),
               fast_gas_price: nil | Decimal.t(),
               average_gas_price: nil | Decimal.t(),
               slow_priority_fee_per_gas: nil | Decimal.t(),
               average_priority_fee_per_gas: nil | Decimal.t(),
               fast_priority_fee_per_gas: nil | Decimal.t(),
               slow_time: nil | Decimal.t(),
               average_time: nil | Decimal.t(),
               fast_time: nil | Decimal.t()
             }
           ]}
        when gas_price: nil | %{price: float(), time: float(), fiat_price: Decimal.t()}
  def get_average_gas_price(num_of_blocks, safelow_percentile, average_percentile, fast_percentile) do
    safelow_percentile_fraction = safelow_percentile / 100
    average_percentile_fraction = average_percentile / 100
    fast_percentile_fraction = fast_percentile / 100

    acc = get_gas_prices_acc()

    from_block =
      case acc do
        [%{block_number: from_block} | _] -> from_block
        _ -> -1
      end

    average_block_time =
      case AverageBlockTime.average_block_time() do
        {:error, _} -> nil
        average_block_time -> average_block_time |> Duration.to_milliseconds()
      end

    fee_query =
      if DenormalizationHelper.denormalization_finished?() do
        from(
          transaction in Transaction,
          where: transaction.block_consensus == true,
          where: transaction.status == ^1,
          where: transaction.gas_price > ^0,
          where: transaction.block_number > ^from_block,
          group_by: transaction.block_number,
          order_by: [desc: transaction.block_number],
          select: %{
            block_number: transaction.block_number,
            slow_gas_price:
              fragment(
                "percentile_disc(? :: real) within group ( order by ? )",
                ^safelow_percentile_fraction,
                transaction.gas_price
              ),
            average_gas_price:
              fragment(
                "percentile_disc(? :: real) within group ( order by ? )",
                ^average_percentile_fraction,
                transaction.gas_price
              ),
            fast_gas_price:
              fragment(
                "percentile_disc(? :: real) within group ( order by ? )",
                ^fast_percentile_fraction,
                transaction.gas_price
              ),
            slow_priority_fee_per_gas:
              fragment(
                "percentile_disc(? :: real) within group ( order by ? )",
                ^safelow_percentile_fraction,
                transaction.max_priority_fee_per_gas
              ),
            average_priority_fee_per_gas:
              fragment(
                "percentile_disc(? :: real) within group ( order by ? )",
                ^average_percentile_fraction,
                transaction.max_priority_fee_per_gas
              ),
            fast_priority_fee_per_gas:
              fragment(
                "percentile_disc(? :: real) within group ( order by ? )",
                ^fast_percentile_fraction,
                transaction.max_priority_fee_per_gas
              ),
            slow_time:
              fragment(
                "percentile_disc(? :: real) within group ( order by coalesce(extract(milliseconds from (?)::interval), ?) desc )",
                ^safelow_percentile_fraction,
                transaction.block_timestamp - transaction.earliest_processing_start,
                ^average_block_time
              ),
            average_time:
              fragment(
                "percentile_disc(? :: real) within group ( order by coalesce(extract(milliseconds from (?)::interval), ?) desc )",
                ^average_percentile_fraction,
                transaction.block_timestamp - transaction.earliest_processing_start,
                ^average_block_time
              ),
            fast_time:
              fragment(
                "percentile_disc(? :: real) within group ( order by coalesce(extract(milliseconds from (?)::interval), ?) desc )",
                ^fast_percentile_fraction,
                transaction.block_timestamp - transaction.earliest_processing_start,
                ^average_block_time
              )
          },
          limit: ^num_of_blocks
        )
      else
        from(
          block in Block,
          left_join: transaction in assoc(block, :transactions),
          where: block.consensus == true,
          where: transaction.status == ^1,
          where: transaction.gas_price > ^0,
          where: transaction.block_number > ^from_block,
          group_by: transaction.block_number,
          order_by: [desc: transaction.block_number],
          select: %{
            block_number: transaction.block_number,
            slow_gas_price:
              fragment(
                "percentile_disc(? :: real) within group ( order by ? )",
                ^safelow_percentile_fraction,
                transaction.gas_price
              ),
            average_gas_price:
              fragment(
                "percentile_disc(? :: real) within group ( order by ? )",
                ^average_percentile_fraction,
                transaction.gas_price
              ),
            fast_gas_price:
              fragment(
                "percentile_disc(? :: real) within group ( order by ? )",
                ^fast_percentile_fraction,
                transaction.gas_price
              ),
            slow_priority_fee_per_gas:
              fragment(
                "percentile_disc(? :: real) within group ( order by ? )",
                ^safelow_percentile_fraction,
                transaction.max_priority_fee_per_gas
              ),
            average_priority_fee_per_gas:
              fragment(
                "percentile_disc(? :: real) within group ( order by ? )",
                ^average_percentile_fraction,
                transaction.max_priority_fee_per_gas
              ),
            fast_priority_fee_per_gas:
              fragment(
                "percentile_disc(? :: real) within group ( order by ? )",
                ^fast_percentile_fraction,
                transaction.max_priority_fee_per_gas
              ),
            slow_time:
              fragment(
                "percentile_disc(? :: real) within group ( order by coalesce(extract(milliseconds from (?)::interval), ?) desc )",
                ^safelow_percentile_fraction,
                block.timestamp - transaction.earliest_processing_start,
                ^average_block_time
              ),
            average_time:
              fragment(
                "percentile_disc(? :: real) within group ( order by coalesce(extract(milliseconds from (?)::interval), ?) desc )",
                ^average_percentile_fraction,
                block.timestamp - transaction.earliest_processing_start,
                ^average_block_time
              ),
            fast_time:
              fragment(
                "percentile_disc(? :: real) within group ( order by coalesce(extract(milliseconds from (?)::interval), ?) desc )",
                ^fast_percentile_fraction,
                block.timestamp - transaction.earliest_processing_start,
                ^average_block_time
              )
          },
          limit: ^num_of_blocks
        )
      end

    new_acc = fee_query |> Repo.all(timeout: :infinity) |> merge_gas_prices(acc, num_of_blocks)

    gas_prices = new_acc |> process_fee_data_from_db()

    {{:ok, gas_prices}, new_acc}
  catch
    error ->
      Logger.error("Failed to get gas prices: #{inspect(error)}")
      {{:error, error}, get_gas_prices_acc()}
  end

  defp merge_gas_prices(new, acc, acc_size), do: Enum.take(new ++ acc, acc_size)

  defp process_fee_data_from_db([]) do
    %{
      slow: nil,
      average: nil,
      fast: nil
    }
  end

  defp process_fee_data_from_db(fees) do
    %{
      slow_gas_price: slow_gas_price,
      average_gas_price: average_gas_price,
      fast_gas_price: fast_gas_price,
      slow_priority_fee_per_gas: slow_priority_fee_per_gas,
      average_priority_fee_per_gas: average_priority_fee_per_gas,
      fast_priority_fee_per_gas: fast_priority_fee_per_gas,
      slow_time: slow_time,
      average_time: average_time,
      fast_time: fast_time
    } = merge_fees(fees)

    json_rpc_named_arguments = Application.get_env(:explorer, :json_rpc_named_arguments)

    {slow_fee, average_fee, fast_fee} =
      case nil not in [slow_priority_fee_per_gas, average_priority_fee_per_gas, fast_priority_fee_per_gas] &&
             EthereumJSONRPC.fetch_block_by_tag("pending", json_rpc_named_arguments) do
        {:ok, %Blocks{blocks_params: [%{base_fee_per_gas: base_fee}]}} when not is_nil(base_fee) ->
          base_fee_wei = base_fee |> Decimal.new() |> Wei.from(:wei)

          {
            priority_with_base_fee(slow_priority_fee_per_gas, base_fee_wei),
            priority_with_base_fee(average_priority_fee_per_gas, base_fee_wei),
            priority_with_base_fee(fast_priority_fee_per_gas, base_fee_wei)
          }

        _ ->
          {gas_price(slow_gas_price), gas_price(average_gas_price), gas_price(fast_gas_price)}
      end

    exchange_rate_from_db = Market.get_coin_exchange_rate()

    %{
      slow: compose_gas_price(slow_fee, slow_time, exchange_rate_from_db),
      average: compose_gas_price(average_fee, average_time, exchange_rate_from_db),
      fast: compose_gas_price(fast_fee, fast_time, exchange_rate_from_db)
    }
  end

  defp merge_fees(fees_from_db) do
    fees_from_db
    |> Stream.map(&Map.delete(&1, :block_number))
    |> Enum.reduce(
      &Map.merge(&1, &2, fn
        _, nil, nil -> nil
        _, val, nil -> [val]
        _, nil, acc -> if is_list(acc), do: acc, else: [acc]
        _, val, acc -> if is_list(acc), do: [val | acc], else: [val, acc]
      end)
    )
    |> Map.new(fn
      {key, nil} ->
        {key, nil}

      {key, value} ->
        value = if is_list(value), do: value, else: [value]
        count = Enum.count(value)
        {key, value |> Enum.reduce(Decimal.new(0), &Decimal.add/2) |> Decimal.div(count)}
    end)
  end

  defp compose_gas_price(fee, time, exchange_rate_from_db) do
    %{
      price: fee |> format_wei(),
      time: time && time |> Decimal.to_float(),
      fiat_price: fiat_fee(fee, exchange_rate_from_db)
    }
  end

  defp fiat_fee(fee, exchange_rate) do
    exchange_rate.usd_value &&
      fee
      |> Wei.to(:ether)
      |> Decimal.mult(exchange_rate.usd_value)
      |> Decimal.mult(simple_transaction_gas())
      |> Decimal.round(2)
  end

  defp priority_with_base_fee(priority, base_fee) do
    priority |> Wei.from(:wei) |> Wei.sum(base_fee)
  end

  defp gas_price(value) do
    value |> Wei.from(:wei)
  end

  defp format_wei(wei), do: wei |> Wei.to(:gwei) |> Decimal.to_float() |> Float.ceil(2)

  defp global_ttl, do: Application.get_env(:explorer, __MODULE__)[:global_ttl]

  defp simple_transaction_gas, do: Application.get_env(:explorer, __MODULE__)[:simple_transaction_gas]

  defp num_of_blocks, do: Application.get_env(:explorer, __MODULE__)[:num_of_blocks]

  defp safelow, do: Application.get_env(:explorer, __MODULE__)[:safelow_percentile]

  defp average, do: Application.get_env(:explorer, __MODULE__)[:average_percentile]

  defp fast, do: Application.get_env(:explorer, __MODULE__)[:fast_percentile]

  defp handle_fallback(:gas_prices) do
    # This will get the task PID if one exists and launch a new task if not
    # See next `handle_fallback` definition
    get_async_task()

    {:return, get_old_gas_prices()}
  end

  defp handle_fallback(:async_task) do
    # If this gets called it means an async task was requested, but none exists
    # so a new one needs to be launched
    {:ok, task} =
      Task.start(fn ->
        try do
          {result, acc} = get_average_gas_price(num_of_blocks(), safelow(), average(), fast())

          set_gas_prices_acc(acc)
          set_gas_prices(%ConCache.Item{ttl: global_ttl(), value: result})
          set_old_updated_at(get_updated_at())
          set_updated_at(DateTime.utc_now())
        rescue
          e ->
            Logger.error([
              "Couldn't update gas used gas_prices",
              Exception.format(:error, e, __STACKTRACE__)
            ])
        end

        set_async_task(nil)
      end)

    {:update, task}
  end

  defp handle_fallback(:gas_prices_acc) do
    {:return, []}
  end

  defp handle_fallback(_), do: {:return, nil}

  # By setting this as a `callback` an async task will be started each time the
  # `gas_prices` expires (unless there is one already running)
  defp async_task_on_deletion({:delete, _, :gas_prices}) do
    set_old_gas_prices(get_gas_prices())
    get_async_task()
  end

  defp async_task_on_deletion(_data), do: nil
end
