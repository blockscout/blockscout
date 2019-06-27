defmodule Explorer.Chain.Supply.RSKTest do
  use Explorer.DataCase

  alias Explorer.Chain.Supply.RSK
  alias Explorer.Chain.Wei
  alias Explorer.ExchangeRates.Token

  @coin_address "0x0000000000000000000000000000000001000006"

  defp wei!(value) do
    {:ok, wei} = Wei.cast(value)
    wei
  end

  test "total is 21_000_000" do
    assert RSK.total() == 21_000_000
  end

  describe "market_cap/1" do
    test "calculates market_cap" do
      address = insert(:address, hash: @coin_address)
      insert(:block, number: 0)
      insert(:fetched_balance, value: 10_000_000_000_000_000_000_000, address_hash: address.hash, block_number: 0)

      exchange_rate = %{Token.null() | usd_value: Decimal.new(10)}

      assert RSK.market_cap(exchange_rate) == Decimal.new(100)
    end
  end

  describe "circulating/0" do
    test "with no balance" do
      assert RSK.circulating() == wei!(0)
    end

    test "with a balance" do
      address = insert(:address, hash: @coin_address)
      insert(:block, number: 0)

      insert(:fetched_balance, value: 10, address_hash: address.hash, block_number: 0)

      assert RSK.circulating() == wei!(10)
    end
  end

  defp date(now, shift \\ []) do
    now
    |> Timex.shift(shift)
    |> Timex.to_date()
  end

  defp dec(number) do
    Decimal.new(number)
  end

  describe "supply_for_days/1" do
    test "when there is no balance" do
      now = Timex.now()

      assert RSK.supply_for_days(2) ==
               {:ok,
                %{
                  date(now, days: -2) => dec(0),
                  date(now, days: -1) => dec(0),
                  date(now) => dec(0)
                }}
    end

    test "when there is a single balance before the days, that balance is used" do
      address = insert(:address, hash: @coin_address)
      now = Timex.now()

      insert(:block, number: 0, timestamp: Timex.shift(now, days: -10))

      insert(:fetched_balance, value: 10, address_hash: address.hash, block_number: 0)

      assert RSK.supply_for_days(2) ==
               {:ok,
                %{
                  date(now, days: -2) => dec(10),
                  date(now, days: -1) => dec(10),
                  date(now) => dec(10)
                }}
    end

    test "when there is a balance for one of the days, days after it use that balance" do
      address = insert(:address, hash: @coin_address)
      now = Timex.now()

      insert(:block, number: 0, timestamp: Timex.shift(now, days: -10))
      insert(:block, number: 1, timestamp: Timex.shift(now, days: -1))

      insert(:fetched_balance, value: 10, address_hash: address.hash, block_number: 0)

      insert(:fetched_balance, value: 20, address_hash: address.hash, block_number: 1)

      assert RSK.supply_for_days(2) ==
               {:ok,
                %{
                  date(now, days: -2) => dec(10),
                  date(now, days: -1) => dec(20),
                  date(now) => dec(20)
                }}
    end

    test "when there is a balance for the first day, that balance is used" do
      address = insert(:address, hash: @coin_address)
      now = Timex.now()

      insert(:block, number: 0, timestamp: Timex.shift(now, days: -10))
      insert(:block, number: 1, timestamp: Timex.shift(now, days: -2))
      insert(:block, number: 2, timestamp: Timex.shift(now, days: -1))

      insert(:fetched_balance, value: 5, address_hash: address.hash, block_number: 0)

      insert(:fetched_balance, value: 10, address_hash: address.hash, block_number: 1)

      insert(:fetched_balance, value: 20, address_hash: address.hash, block_number: 2)

      assert RSK.supply_for_days(2) ==
               {:ok,
                %{
                  date(now, days: -2) => dec(10),
                  date(now, days: -1) => dec(20),
                  date(now) => dec(20)
                }}
    end

    test "when there is a balance for all days, they are each used correctly" do
      address = insert(:address, hash: @coin_address)
      now = Timex.now()

      insert(:block, number: 0, timestamp: Timex.shift(now, days: -10))
      insert(:block, number: 1, timestamp: Timex.shift(now, days: -2))
      insert(:block, number: 2, timestamp: Timex.shift(now, days: -1))
      insert(:block, number: 3, timestamp: now)

      insert(:fetched_balance, value: 5, address_hash: address.hash, block_number: 0)
      insert(:fetched_balance, value: 10, address_hash: address.hash, block_number: 1)
      insert(:fetched_balance, value: 20, address_hash: address.hash, block_number: 2)
      insert(:fetched_balance, value: 30, address_hash: address.hash, block_number: 3)

      assert RSK.supply_for_days(2) ==
               {:ok,
                %{
                  date(now, days: -2) => dec(10),
                  date(now, days: -1) => dec(20),
                  date(now) => dec(30)
                }}
    end
  end
end
