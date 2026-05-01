defmodule BlockScoutWeb.API.V2.AddressViewTest do
  use BlockScoutWeb.ConnCase, async: true

  alias BlockScoutWeb.API.V2.AddressView
  alias Explorer.Chain.Wei

  describe "prepare_coin_balance_history_entry/1" do
    test "returns map with expected keys and values" do
      block_timestamp = ~U[2023-01-01 00:00:00Z]
      delta = Decimal.new(100)
      value = Decimal.new(200)

      coin_balance = %{
        transaction_hash: nil,
        block_number: 10,
        delta: delta,
        value: value,
        block_timestamp: block_timestamp
      }

      result = AddressView.prepare_coin_balance_history_entry(coin_balance)

      assert result["transaction_hash"] == nil
      assert result["block_number"] == 10
      assert Decimal.equal?(result["delta"], delta)
      assert Decimal.equal?(result["value"], value)
      assert result["block_timestamp"] == block_timestamp
    end
  end

  describe "prepare_coin_balance_history_by_day_entry/1" do
    test "returns date and value" do
      value = Decimal.new(500)
      coin_balance_by_day = %{date: ~D[2023-01-01], value: value}

      result = AddressView.prepare_coin_balance_history_by_day_entry(coin_balance_by_day)

      assert result["date"] == ~D[2023-01-01]
      assert Decimal.equal?(result["value"], value)
    end
  end

  describe "prepare_address_for_list/1" do
    test "includes coin balance and transaction count" do
      address =
        build(:address,
          fetched_coin_balance: %Wei{value: Decimal.new(100)},
          transactions_count: 5
        )

      result = AddressView.prepare_address_for_list(address)

      assert Decimal.equal?(result[:coin_balance], Decimal.new(100))
      assert result[:transactions_count] == "5"
      assert Map.has_key?(result, "hash")
    end

    test "sets coin balance to nil when fetched coin balance is missing" do
      address = build(:address, fetched_coin_balance: nil, transactions_count: 3)

      result = AddressView.prepare_address_for_list(address)

      assert result[:coin_balance] == nil
      assert result[:transactions_count] == "3"
    end
  end
end
