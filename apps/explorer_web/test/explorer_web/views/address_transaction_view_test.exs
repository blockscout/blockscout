defmodule ExplorerWeb.AddressTransactionViewTest do
  use Explorer.DataCase

  alias ExplorerWeb.AddressTransactionView

  describe "fee/0" do
    test "formats the fee for a successful transaction" do
      insert(:block, number: 24)
      time = Timex.now() |> Timex.shift(hours: -2)

      block =
        insert(:block, %{
          number: 1,
          gas_used: 99523,
          timestamp: time
        })

      to_address = insert(:address)
      from_address = insert(:address)

      transaction =
        insert(
          :transaction,
          block_hash: block.hash,
          from_address_hash: from_address.hash,
          gas_price: Decimal.new(1_000_000_000.0),
          index: 0,
          inserted_at: Timex.parse!("1970-01-01T00:00:18-00:00", "{ISO:Extended}"),
          to_address_hash: to_address.hash,
          updated_at: Timex.parse!("1980-01-01T00:00:18-00:00", "{ISO:Extended}")
        )

      insert(
        :receipt,
        gas_used: Decimal.new(435_334),
        status: :ok,
        transaction_hash: transaction.hash,
        transaction_index: transaction.index
      )

      transaction =
        transaction
        |> Repo.preload([:receipt])

      assert AddressTransactionView.fee(transaction) == "0.000,435,334,000,000,000"
    end

    test "fee returns max_gas for pending transaction" do
      to_address = insert(:address)
      from_address = insert(:address)

      transaction =
        insert(
          :transaction,
          from_address_hash: from_address.hash,
          gas: Decimal.new(21000.0),
          gas_price: Decimal.new(1_000_000_000.0),
          inserted_at: Timex.parse!("1970-01-01T00:00:18-00:00", "{ISO:Extended}"),
          to_address_hash: to_address.hash,
          updated_at: Timex.parse!("1980-01-01T00:00:18-00:00", "{ISO:Extended}")
        )
        |> Repo.preload([:to_address, :from_address, :receipt])

      assert AddressTransactionView.fee(transaction) == "<= 0.000,021,000,000,000,000"
    end
  end
end
