defmodule Explorer.Chain.Supply.RSK do
  @moduledoc """
  Defines the supply API for calculating supply for coins from RSK.
  """

  use Explorer.Chain.Supply

  import Ecto.Query, only: [from: 2]
  import EthereumJSONRPC, only: [integer_to_quantity: 1]

  alias EthereumJSONRPC.FetchedBalances
  alias Explorer.Chain.Address.CoinBalance
  alias Explorer.Chain.{Block, Wei}
  alias Explorer.Chain.Cache.BlockNumber
  alias Explorer.Repo

  @cache_name :rsk_balance
  @balance_key :balance

  def market_cap(%{usd_value: usd_value}) when not is_nil(usd_value) do
    btc = circulating()

    Decimal.mult(btc, usd_value)
  end

  def market_cap(_), do: Decimal.new(0)

  @doc "Equivalent to getting the circulating value "
  def supply_for_days(days) do
    now = Timex.now()

    balances_query =
      from(balance in CoinBalance,
        join: block in Block,
        on: block.number == balance.block_number,
        where: block.consensus == true,
        where: balance.address_hash == ^"0x0000000000000000000000000000000001000006",
        where: block.timestamp > ^Timex.shift(now, days: -days),
        distinct: fragment("date_trunc('day', ?)", block.timestamp),
        select: {block.timestamp, balance.value}
      )

    balance_before_query =
      from(balance in CoinBalance,
        join: block in Block,
        on: block.number == balance.block_number,
        where: block.consensus == true,
        where: balance.address_hash == ^"0x0000000000000000000000000000000001000006",
        where: block.timestamp <= ^Timex.shift(Timex.now(), days: -days),
        order_by: [desc: block.timestamp],
        limit: 1,
        select: balance.value
      )

    by_day =
      balances_query
      |> Repo.all()
      |> Enum.into(%{}, fn {timestamp, value} ->
        {Timex.to_date(timestamp), value}
      end)

    starting = Repo.one(balance_before_query) || wei!(0)

    result =
      -days..0
      |> Enum.reduce({%{}, starting.value}, fn i, {days, last} ->
        date =
          now
          |> Timex.shift(days: i)
          |> Timex.to_date()

        cur_value =
          case Map.get(by_day, date) do
            nil ->
              last

            value ->
              value.value
          end

        {Map.put(days, date, calculate_value(cur_value)), cur_value}
      end)
      |> elem(0)

    {:ok, result}
  end

  def circulating do
    value = ConCache.get(@cache_name, @balance_key)

    if is_nil(value) do
      updated_value = fetch_circulating_value()

      ConCache.put(@cache_name, @balance_key, updated_value)

      updated_value
    else
      value
    end
  end

  def cache_name, do: @cache_name

  defp fetch_circulating_value do
    max_number = BlockNumber.get_max()

    params = [
      %{block_quantity: integer_to_quantity(max_number), hash_data: "0x0000000000000000000000000000000001000006"}
    ]

    json_rpc_named_arguments = Application.get_env(:explorer, :json_rpc_named_arguments)

    case EthereumJSONRPC.fetch_balances(params, json_rpc_named_arguments) do
      {:ok,
       %FetchedBalances{
         errors: [],
         params_list: [
           %{
             address_hash: "0x0000000000000000000000000000000001000006",
             value: value
           }
         ]
       }} ->
        calculate_value(value)

      _ ->
        Decimal.new(0)
    end
  rescue
    _ -> Decimal.new(0)
  end

  defp wei!(value) do
    {:ok, wei} = Wei.cast(value)
    wei
  end

  def total do
    Decimal.new(21_000_000)
  end

  defp calculate_value(val) do
    sub =
      val
      |> Decimal.new()
      |> Decimal.div(Decimal.new(1_000_000_000_000_000_000))

    Decimal.sub(total(), sub)
  end
end
