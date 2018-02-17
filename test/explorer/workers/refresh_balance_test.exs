defmodule Explorer.Workers.RefreshBalanceTest do
  use Explorer.DataCase

  import Mock

  alias Explorer.Credit
  alias Explorer.Debit
  alias Explorer.Workers.RefreshBalance

  describe "perform/0" do
    test "refreshes credit balances" do
      with_mock Exq, [enqueue: fn (_, _, _, [type]) -> RefreshBalance.perform(type) end] do
        address = insert(:address)
        transaction = insert(:transaction, value: 20)
        insert(:to_address, address: address, transaction: transaction)
        insert(:receipt, transaction: transaction, status: 1)
        RefreshBalance.perform
        assert Repo.one(Credit).value == Decimal.new(20)
      end
    end

    test "refreshes debit balances" do
      with_mock Exq, [enqueue: fn (_, _, _, [type]) -> RefreshBalance.perform(type) end] do
        address = insert(:address)
        transaction = insert(:transaction, value: 20)
        insert(:from_address, address: address, transaction: transaction)
        insert(:receipt, transaction: transaction, status: 1)
        RefreshBalance.perform
        assert Repo.one(Debit).value == Decimal.new(20)
      end
    end
  end

  describe "perform/1" do
    test "refreshes credit balances" do
      address = insert(:address)
      transaction = insert(:transaction, value: 20)
      insert(:to_address, address: address, transaction: transaction)
      insert(:receipt, transaction: transaction, status: 1)
      RefreshBalance.perform("credit")
      assert Repo.one(Credit).value == Decimal.new(20)
    end

    test "refreshes debit balances" do
      address = insert(:address)
      transaction = insert(:transaction, value: 20)
      insert(:from_address, address: address, transaction: transaction)
      insert(:receipt, transaction: transaction, status: 1)
      RefreshBalance.perform("debit")
      assert Repo.one(Debit).value == Decimal.new(20)
    end
  end
end
