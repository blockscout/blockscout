defmodule Explorer.CreditTest do
  use Explorer.DataCase

  alias Explorer.Credit

  describe "Repo.all/1" do
    test "returns no rows when there are no addresses" do
      assert Repo.all(Credit) == []
    end

    test "returns nothing when an address has no transactions" do
      insert(:address)
      Credit.refresh()
      assert Repo.one(Credit) == nil
    end

    test "returns a credit when there is an address with a receipt" do
      receipient = insert(:address)
      sender = insert(:address)
      transaction = insert(:transaction)
      insert(:receipt, transaction: transaction, status: 1)
      insert(:from_address, transaction: transaction, address: sender)
      insert(:to_address, transaction: transaction, address: receipient)
      Credit.refresh()
      credits = Credit |> Repo.all()
      assert credits |> Enum.count() == 1
    end

    test "returns no credits to the sender" do
      receipient = insert(:address)
      sender = insert(:address)
      transaction = insert(:transaction, value: 21)
      insert(:receipt, transaction: transaction, status: 1)
      insert(:from_address, transaction: transaction, address: sender)
      insert(:to_address, transaction: transaction, address: receipient)
      address_id = sender.id
      Credit.refresh()
      credit = Credit |> where(address_id: ^address_id) |> Repo.one()
      assert credit == nil
    end

    test "returns a credit to the receipient" do
      receipient = insert(:address)
      sender = insert(:address)
      transaction = insert(:transaction, value: 21)
      insert(:receipt, transaction: transaction, status: 1)
      insert(:from_address, transaction: transaction, address: sender)
      insert(:to_address, transaction: transaction, address: receipient)
      address_id = receipient.id
      Credit.refresh()
      credit = Credit |> where(address_id: ^address_id) |> Repo.one()
      assert credit.value == Decimal.new(21)
    end
  end
end
