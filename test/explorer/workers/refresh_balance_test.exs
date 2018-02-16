defmodule Explorer.Workers.RefreshBalanceTest do
  use Explorer.DataCase

  alias Explorer.Credit
  alias Explorer.Debit
  alias Explorer.Workers.RefreshBalance

  describe "perform/1" do
    test "refreshes credit balances" do
      address = insert(:address)
      transaction = insert(:transaction, value: 20)
      insert(:to_address, address: address, transaction: transaction)
      RefreshBalance.perform
      assert Repo.one(Credit).value == Decimal.new(20)
    end

    test "refreshes debit balances" do
      address = insert(:address)
      transaction = insert(:transaction, value: 20)
      insert(:from_address, address: address, transaction: transaction)
      RefreshBalance.perform
      assert Repo.one(Debit).value == Decimal.new(20)
    end
  end
end
