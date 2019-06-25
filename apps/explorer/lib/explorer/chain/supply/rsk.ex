defmodule Explorer.Chain.Supply.RSK do
  @moduledoc """
  Defines the supply API for calculating supply for coins from RSK.
  """

  use Explorer.Chain.Supply

  import Ecto.Query, only: [from: 2]

  alias Explorer.Chain.Address.CoinBalance
  alias Explorer.Chain.{Block, Wei}
  alias Explorer.Repo

  def market_cap(exchange_rate) do
    ether = Wei.to(circulating(), :ether)

    Decimal.mult(ether, exchange_rate.usd_value)
  end

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

        case Map.get(by_day, date) do
          nil ->
            {Map.put(days, date, last), last}

          value ->
            {Map.put(days, date, value.value), value.value}
        end
      end)
      |> elem(0)

    {:ok, result}
  end

  def circulating do
    query =
      from(balance in CoinBalance,
        join: block in Block,
        on: block.number == balance.block_number,
        where: block.consensus == true,
        where: balance.address_hash == ^"0x0000000000000000000000000000000001000006",
        order_by: [desc: block.timestamp],
        limit: 1,
        select: balance.value
      )

    Repo.one(query) || wei!(0)
  end

  defp wei!(value) do
    {:ok, wei} = Wei.cast(value)
    wei
  end

  def total do
    21_000_000
  end
end
