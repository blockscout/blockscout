defmodule ExplorerWeb.TransactionViewTest do
  use ExplorerWeb.ConnCase, async: true

  alias Explorer.Chain.{Transaction, Wei}
  alias Explorer.ExchangeRates.Token
  alias Explorer.Repo
  alias ExplorerWeb.TransactionView

  describe "formatted_fee/2" do
    test "pending transaction with no Receipt" do
      {:ok, gas_price} = Wei.cast(3_000_000_000)

      transaction =
        build(
          :transaction,
          gas_price: gas_price,
          gas: Decimal.new(3_000_000),
          receipt: nil
        )

      token = %Token{usd_value: Decimal.new(0.50)}

      expected_value = "<= 0.009,000,000,000,000,000 POA"
      assert expected_value == TransactionView.formatted_fee(transaction, denomination: :ether)
      assert "<= $0.0045 USD" == TransactionView.formatted_fee(transaction, exchange_rate: token)
    end

    test "with fee and exchange_rate" do
      {:ok, gas_price} = Wei.cast(3_000_000_000)
      receipt = build(:receipt, gas_used: Decimal.new(1_034_234.0))
      transaction = build(:transaction, gas_price: gas_price, receipt: receipt)
      token = %Token{usd_value: Decimal.new(0.50)}

      expected_value = "0.003,102,702,000,000,000 POA"
      assert expected_value == TransactionView.formatted_fee(transaction, denomination: :ether)
      assert "$0.0015513510 USD" == TransactionView.formatted_fee(transaction, exchange_rate: token)
    end

    test "with fee but no available exchange_rate" do
    end
  end

  describe "formatted_status/1" do
    test "without receipt" do
      transaction =
        :transaction
        |> insert()
        |> Repo.preload(:receipt)

      assert TransactionView.formatted_status(transaction) == "Pending"
    end

    test "with receipt with status :error with gas_used < gas" do
      gas = 2
      block = insert(:block)
      %Transaction{hash: hash, index: index} = insert(:transaction, block_hash: block.hash, gas: gas, index: 0)
      insert(:receipt, gas_used: gas - 1, status: :error, transaction_hash: hash, transaction_index: index)

      transaction =
        Transaction
        |> Repo.get!(hash)
        |> Repo.preload(:receipt)

      assert TransactionView.formatted_status(transaction) == "Failed"
    end

    test "with receipt with status :error with gas <= gas_used" do
      gas = 2
      block = insert(:block)
      %Transaction{hash: hash, index: index} = insert(:transaction, block_hash: block.hash, gas: gas, index: 0)
      insert(:receipt, gas_used: gas, status: 0, transaction_hash: hash, transaction_index: index)

      transaction =
        Transaction
        |> Repo.get!(hash)
        |> Repo.preload(:receipt)

      assert TransactionView.formatted_status(transaction) == "Out of Gas"
    end

    test "with receipt with status :ok" do
      gas = 2
      block = insert(:block)
      %Transaction{hash: hash, index: index} = insert(:transaction, block_hash: block.hash, gas: gas, index: 0)
      insert(:receipt, gas_used: gas - 1, status: :ok, transaction_hash: hash, transaction_index: index)

      transaction =
        Transaction
        |> Repo.get!(hash)
        |> Repo.preload(:receipt)

      assert TransactionView.formatted_status(transaction) == "Success"
    end
  end
end
