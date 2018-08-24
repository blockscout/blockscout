defmodule BlockScoutWeb.TransactionViewTest do
  use BlockScoutWeb.ConnCase, async: true

  alias Explorer.Chain.Wei
  alias Explorer.ExchangeRates.Token
  alias Explorer.Repo
  alias BlockScoutWeb.TransactionView

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

  describe "involves_token_transfers_and_transferred_value?/1" do
    test "returns true when transaction is greater than 0 and has troken transfers" do
      token_contract_address = insert(:contract_address)

      token = insert(:token, contract_address: token_contract_address)

      transaction =
        :transaction
        |> insert(value: 5)
        |> with_block()

      insert(
        :token_transfer,
        to_address: build(:address),
        transaction: transaction,
        token_contract_address: token_contract_address,
        token: token
      )

      transaction_preloaded = Repo.preload(transaction, :token_transfers)

      assert TransactionView.involves_token_transfers_and_transferred_value?(transaction_preloaded) == true
    end

    test "returns false when transaction is equals 0 and has troken transfers" do
      transaction = insert(:transaction, value: 0)

      assert TransactionView.involves_token_transfers_and_transferred_value?(transaction) == false
    end
  end

  describe "display_transaction_info?/1" do
    test "returns true when transaction is not a token transfer" do
      transaction = build(:transaction, value: 0)

      assert TransactionView.display_transaction_info?(transaction) == true
    end

    test "returns true when transaction value is greater than 0 and has troken transfers" do
      token_contract_address = insert(:contract_address)

      token = insert(:token, contract_address: token_contract_address)

      transaction =
        :transaction
        |> insert(value: 5)
        |> with_block()

      insert(
        :token_transfer,
        to_address: build(:address),
        transaction: transaction,
        token_contract_address: token_contract_address,
        token: token
      )

      transaction_preloaded = Repo.preload(transaction, :token_transfers)

      assert TransactionView.display_transaction_info?(transaction_preloaded) == true
    end

    test "return false when transaction value is equals 0 and has token transfers" do
      token_contract_address = insert(:contract_address)

      token = insert(:token, contract_address: token_contract_address)

      transaction =
        :transaction
        |> insert(value: 0)
        |> with_block()

      insert(
        :token_transfer,
        to_address: build(:address),
        transaction: transaction,
        token_contract_address: token_contract_address,
        token: token
      )

      transaction_preloaded = Repo.preload(transaction, :token_transfers)

      assert TransactionView.display_transaction_info?(transaction_preloaded) == false
    end
  end

  describe "more_than_one_token_transfer?/1" do
    test "returns true when the transaction has more than one token transfer" do
      token_contract_address = insert(:contract_address)

      token = insert(:token, contract_address: token_contract_address)

      transaction =
        :transaction
        |> insert(value: 0)
        |> with_block()

      insert(
        :token_transfer,
        to_address: build(:address),
        transaction: transaction,
        token_contract_address: token_contract_address,
        token: token
      )

      insert(
        :token_transfer,
        to_address: build(:address),
        transaction: transaction,
        token_contract_address: token_contract_address,
        token: token
      )

      transaction_preloaded = Repo.preload(transaction, :token_transfers)

      assert TransactionView.more_than_one_token_transfer?(transaction_preloaded) == true
    end

    test "returns false when the transaction has only one token transfer" do
      token_contract_address = insert(:contract_address)

      token = insert(:token, contract_address: token_contract_address)

      transaction =
        :transaction
        |> insert(value: 0)
        |> with_block()

      insert(
        :token_transfer,
        to_address: build(:address),
        transaction: transaction,
        token_contract_address: token_contract_address,
        token: token
      )

      transaction_preloaded = Repo.preload(transaction, :token_transfers)

      assert TransactionView.more_than_one_token_transfer?(transaction_preloaded) == false
    end
  end

  describe "first_token_transfer/1" do
    test "returns the transaction first token transfer" do
      token_contract_address = insert(:contract_address)

      token = insert(:token, contract_address: token_contract_address)

      transaction =
        :transaction
        |> insert(value: 0)
        |> with_block()

      token_transfer =
        insert(
          :token_transfer,
          to_address: build(:address),
          transaction: transaction,
          token_contract_address: token_contract_address,
          token: token
        )

      insert(
        :token_transfer,
        to_address: build(:address),
        transaction: transaction,
        token_contract_address: token_contract_address,
        token: token
      )

      transaction_preloaded = Repo.preload(transaction, :token_transfers)

      first_token_transfer = TransactionView.first_token_transfer(transaction_preloaded)

      assert first_token_transfer.id == token_transfer.id
    end

    test "returns nothing when the transaction doesn't have a token transfer" do
      token_contract_address = insert(:contract_address)

      insert(:token, contract_address: token_contract_address)

      transaction =
        :transaction
        |> insert(value: 0)
        |> with_block()

      transaction_preloaded = Repo.preload(transaction, :token_transfers)

      assert TransactionView.first_token_transfer(transaction_preloaded) == nil
    end
  end

  describe "token_transfers_left_to_show/1" do
    test "returns how many token transfers are left to be shown, besides the first one" do
      token_contract_address = insert(:contract_address)

      token = insert(:token, contract_address: token_contract_address)

      transaction =
        :transaction
        |> insert(value: 0)
        |> with_block()

      insert(
        :token_transfer,
        to_address: build(:address),
        transaction: transaction,
        token_contract_address: token_contract_address,
        token: token
      )

      insert(
        :token_transfer,
        to_address: build(:address),
        transaction: transaction,
        token_contract_address: token_contract_address,
        token: token
      )

      transaction_preloaded = Repo.preload(transaction, :token_transfers)

      assert TransactionView.token_transfers_left_to_show(transaction_preloaded) == 1
    end
  end
end
