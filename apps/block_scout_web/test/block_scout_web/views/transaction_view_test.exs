defmodule BlockScoutWeb.TransactionViewTest do
  use BlockScoutWeb.ConnCase, async: true

  alias Explorer.Chain.Wei
  alias Explorer.Repo
  alias BlockScoutWeb.TransactionView

  describe "confirmations/2" do
    test "returns 0 if pending transaction" do
      transaction = build(:transaction, block: nil)

      assert 0 == TransactionView.confirmations(transaction, [])
    end

    test "returns string of number of blocks validated since subject block" do
      block = insert(:block)

      transaction =
        :transaction
        |> insert()
        |> with_block(block)

      assert "1" == TransactionView.confirmations(transaction, max_block_number: block.number + 1)
    end
  end

  describe "contract_creation?/1" do
    test "returns true if contract creation transaction" do
      assert TransactionView.contract_creation?(build(:transaction, to_address: nil))
    end

    test "returns false if not contract" do
      refute TransactionView.contract_creation?(build(:transaction))
    end
  end

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

      expected_value = "Max of 0.009 POA"
      assert expected_value == TransactionView.formatted_fee(transaction, denomination: :ether)
    end

    test "with fee" do
      {:ok, gas_price} = Wei.cast(3_000_000_000)
      transaction = build(:transaction, gas_price: gas_price, gas_used: Decimal.new(1_034_234.0))

      expected_value = "0.003102702 POA"
      assert expected_value == TransactionView.formatted_fee(transaction, denomination: :ether)
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

  test "gas/1 returns the gas as a string" do
    assert "2" == TransactionView.gas(build(:transaction, gas: 2))
  end

  test "hash/1 returns the hash as a string" do
    assert "test" == TransactionView.hash(build(:transaction, hash: "test"))
  end

  describe "qr_code/1" do
    test "it returns an encoded value" do
      transaction = build(:transaction)
      assert {:ok, _} = Base.decode64(TransactionView.qr_code(transaction))
    end
  end

  describe "to_address_hash/1" do
    test "returns contract address for created contract transaction" do
      contract = insert(:contract_address)
      transaction = insert(:transaction, to_address: nil, created_contract_address: contract)
      assert contract.hash == TransactionView.to_address_hash(transaction)
    end

    test "returns hash for transaction" do
      address = insert(:address)
      transaction = insert(:transaction, to_address: address)
      assert address.hash == TransactionView.to_address_hash(transaction)
    end
  end
end
