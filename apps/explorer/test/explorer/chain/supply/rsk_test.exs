defmodule Explorer.Chain.Supply.RSKTest do
  use Explorer.DataCase

  import Mox

  alias Explorer.Chain.Supply.RSK
  alias Explorer.ExchangeRates.Token

  @coin_address "0x0000000000000000000000000000000001000006"
  @mult 1_000_000_000_000_000_000

  test "total is 21_000_000" do
    assert Decimal.equal?(RSK.total(), Decimal.new(21_000_000))
  end

  describe "market_cap/1" do
    @tag :no_parity
    @tag :no_geth
    test "calculates market_cap" do
      EthereumJSONRPC.Mox
      |> expect(:json_rpc, fn [%{id: id, method: "eth_getBalance"}], _options ->
        {:ok, [%{id: id, result: "20999999999900000000000000"}]}
      end)

      exchange_rate = %{Token.null() | usd_value: Decimal.new(1_000_000)}

      assert Decimal.equal?(RSK.market_cap(exchange_rate), Decimal.from_float(100.0000))
    end

    test "returns zero when exchange_rate is empty" do
      assert RSK.market_cap(nil) == Decimal.new(0)
    end

    test "returns zero when usd_value is nil" do
      exchange_rate = %{Token.null() | usd_value: nil}

      assert RSK.market_cap(exchange_rate) == Decimal.new(0)
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
                  date(now, days: -2) => dec(21_000_000),
                  date(now, days: -1) => dec(21_000_000),
                  date(now) => dec(21_000_000)
                }}
    end

    test "when there is a single balance before the days, that balance is used" do
      address = insert(:address, hash: @coin_address)
      now = Timex.now()

      insert(:block, number: 0, timestamp: Timex.shift(now, days: -10))

      insert(:fetched_balance, value: 10 * @mult, address_hash: address.hash, block_number: 0)

      assert RSK.supply_for_days(2) ==
               {:ok,
                %{
                  date(now, days: -2) => dec(20_999_990),
                  date(now, days: -1) => dec(20_999_990),
                  date(now) => dec(20_999_990)
                }}
    end

    test "when there is a balance for one of the days, days after it use that balance" do
      address = insert(:address, hash: @coin_address)
      now = Timex.now()

      insert(:block, number: 0, timestamp: Timex.shift(now, days: -10))
      insert(:block, number: 1, timestamp: Timex.shift(now, days: -1))

      insert(:fetched_balance, value: 10 * @mult, address_hash: address.hash, block_number: 0)

      insert(:fetched_balance, value: 20 * @mult, address_hash: address.hash, block_number: 1)

      assert RSK.supply_for_days(2) ==
               {:ok,
                %{
                  date(now, days: -2) => dec(20_999_990),
                  date(now, days: -1) => dec(20_999_980),
                  date(now) => dec(20_999_980)
                }}
    end

    test "when there is a balance for the first day, that balance is used" do
      address = insert(:address, hash: @coin_address)
      now = Timex.now()

      insert(:block, number: 0, timestamp: Timex.shift(now, days: -10))
      insert(:block, number: 1, timestamp: Timex.shift(now, days: -2))
      insert(:block, number: 2, timestamp: Timex.shift(now, days: -1))

      insert(:fetched_balance, value: 5 * @mult, address_hash: address.hash, block_number: 0)

      insert(:fetched_balance, value: 10 * @mult, address_hash: address.hash, block_number: 1)

      insert(:fetched_balance, value: 20 * @mult, address_hash: address.hash, block_number: 2)

      assert RSK.supply_for_days(2) ==
               {:ok,
                %{
                  date(now, days: -2) => dec(20_999_990),
                  date(now, days: -1) => dec(20_999_980),
                  date(now) => dec(20_999_980)
                }}
    end

    test "when there is a balance for all days, they are each used correctly" do
      address = insert(:address, hash: @coin_address)
      now = Timex.now()

      insert(:block, number: 0, timestamp: Timex.shift(now, days: -10))
      insert(:block, number: 1, timestamp: Timex.shift(now, days: -2))
      insert(:block, number: 2, timestamp: Timex.shift(now, days: -1))
      insert(:block, number: 3, timestamp: now)

      insert(:fetched_balance, value: 5 * @mult, address_hash: address.hash, block_number: 0)
      insert(:fetched_balance, value: 10 * @mult, address_hash: address.hash, block_number: 1)
      insert(:fetched_balance, value: 20 * @mult, address_hash: address.hash, block_number: 2)
      insert(:fetched_balance, value: 30 * @mult, address_hash: address.hash, block_number: 3)

      assert RSK.supply_for_days(2) ==
               {:ok,
                %{
                  date(now, days: -2) => dec(20_999_990),
                  date(now, days: -1) => dec(20_999_980),
                  date(now) => dec(20_999_970)
                }}
    end
  end
end
