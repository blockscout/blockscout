defmodule BlockScoutWeb.InternalTransactionViewTest do
  use BlockScoutWeb.ConnCase, async: true

  alias BlockScoutWeb.InternalTransactionView

  describe "create?/1" do
    test "with internal transaction of type create returns true" do
      internal_transaction = build(:internal_transaction_create)

      assert InternalTransactionView.create?(internal_transaction)
    end

    test "with non-create type internal transaction returns false" do
      internal_transaction = build(:internal_transaction)

      refute InternalTransactionView.create?(internal_transaction)
    end
  end

  describe "to_address_hash/1" do
    setup do
      transaction = insert(:transaction)
      {:ok, transaction: transaction}
    end

    test "with a contract address", %{transaction: transaction} do
      internal_transaction = insert(:internal_transaction_create, transaction: transaction, index: 1)

      assert InternalTransactionView.to_address_hash(internal_transaction) ==
               internal_transaction.created_contract_address_hash
    end

    test "without a contract address", %{transaction: transaction} do
      internal_transaction = insert(:internal_transaction, transaction: transaction, index: 1)

      assert InternalTransactionView.to_address_hash(internal_transaction) == internal_transaction.to_address_hash
    end
  end

  describe "to_address/1" do
    setup do
      transaction = insert(:transaction)
      {:ok, transaction: transaction}
    end

    test "with a contract address", %{transaction: transaction} do
      internal_transaction = insert(:internal_transaction_create, transaction: transaction, index: 1)
      preloaded_internal_transaction = Explorer.Repo.preload(internal_transaction, :to_address)

      assert InternalTransactionView.to_address(preloaded_internal_transaction) ==
               preloaded_internal_transaction.created_contract_address
    end

    test "without a contract address", %{transaction: transaction} do
      internal_transaction = insert(:internal_transaction, transaction: transaction, index: 1)
      preloaded_internal_transaction = Explorer.Repo.preload(internal_transaction, :created_contract_address)

      assert InternalTransactionView.to_address(preloaded_internal_transaction) ==
               preloaded_internal_transaction.to_address
    end
  end
end
