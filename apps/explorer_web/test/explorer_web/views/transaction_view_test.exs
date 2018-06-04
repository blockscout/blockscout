defmodule ExplorerWeb.TransactionViewTest do
  use ExplorerWeb.ConnCase, async: true

  alias Explorer.Chain.Wei
  alias Explorer.ExchangeRates.Token
  alias Explorer.Repo
  alias ExplorerWeb.TransactionView

  describe "formatted_fee/2" do
    test "pending transaction with no Receipt" do
      {:ok, gas_price} = Wei.cast(3_000_000_000)

      transaction =
        build(
          :transaction,
          gas: Decimal.new(3_000_000),
          gas_price: gas_price,
          gas_used: nil
        )

      token = %Token{usd_value: Decimal.new(0.50)}

      expected_value = "<= 0.009 POA"
      assert expected_value == TransactionView.formatted_fee(transaction, denomination: :ether)
      assert "<= $0.0045 USD" == TransactionView.formatted_fee(transaction, exchange_rate: token)
    end

    test "with fee and exchange_rate" do
      {:ok, gas_price} = Wei.cast(3_000_000_000)
      transaction = build(:transaction, gas_price: gas_price, gas_used: Decimal.new(1_034_234.0))
      token = %Token{usd_value: Decimal.new(0.50)}

      expected_value = "0.003102702 POA"
      assert expected_value == TransactionView.formatted_fee(transaction, denomination: :ether)
      assert "$0.001551351 USD" == TransactionView.formatted_fee(transaction, exchange_rate: token)
    end

    test "with fee but no available exchange_rate" do
    end
  end

  describe "formatted_status/1" do
    test "without block" do
      transaction =
        :transaction
        |> insert()
        |> Repo.preload(:block)

      assert TransactionView.formatted_status(transaction) == "Pending"
    end

    test "with block with status :error with gas_used < gas" do
      gas = 2
      block = insert(:block)

      transaction =
        :transaction
        |> insert(gas: gas)
        |> with_block(block, gas_used: gas - 1, status: :error)

      assert TransactionView.formatted_status(transaction) == "Failed"
    end

    test "with block with status :error with gas <= gas_used" do
      gas = 2

      transaction =
        :transaction
        |> insert(gas: gas)
        |> with_block(gas_used: gas, status: :error)

      assert TransactionView.formatted_status(transaction) == "Out of Gas"
    end

    test "with receipt with status :ok" do
      gas = 2

      transaction =
        :transaction
        |> insert(gas: gas)
        |> with_block(gas_used: gas - 1, status: :ok)

      assert TransactionView.formatted_status(transaction) == "Success"
    end
  end

  describe "qr_code/1" do
    test "it returns an encoded value" do
      transaction = build(:transaction)
      assert {:ok, _} = Base.decode64(TransactionView.qr_code(transaction))
    end
  end
end
