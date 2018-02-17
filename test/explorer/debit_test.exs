defmodule Explorer.DebitTest do
  use Explorer.DataCase

  alias Explorer.Debit

  describe "Repo.all/1" do
    test "returns no rows when there are no addresses" do
      assert Repo.all(Debit) == []
    end

    test "returns nothing when an address has no transactions" do
      insert(:address)
      Debit.refresh
      assert Repo.one(Debit) == nil
    end

    test "returns a debit when there is an address with a receipt" do
      receipient = insert(:address)
      sender = insert(:address)
      transaction = insert(:transaction)
      insert(:receipt, transaction: transaction, status: 1)
      insert(:from_address, transaction: transaction, address: sender)
      insert(:to_address, transaction: transaction, address: receipient)
      Debit.refresh
      debits = Debit |> Repo.all
      assert debits |> Enum.count == 1
    end

    test "returns a debit against the sender" do
      receipient = insert(:address)
      sender = insert(:address)
      transaction = insert(:transaction, value: 21)
      insert(:receipt, transaction: transaction, status: 1)
      insert(:from_address, transaction: transaction, address: sender)
      insert(:to_address, transaction: transaction, address: receipient)
      address_id = sender.id
      Debit.refresh
      debit = Debit |> where(address_id: ^address_id) |> Repo.one
      assert debit.value == Decimal.new(21)
    end

    test "returns no debits against the receipient" do
      receipient = insert(:address)
      sender = insert(:address)
      transaction = insert(:transaction, value: 21)
      insert(:receipt, transaction: transaction, status: 1)
      insert(:from_address, transaction: transaction, address: sender)
      insert(:to_address, transaction: transaction, address: receipient)
      address_id = receipient.id
      Debit.refresh
      debit = Debit |> where(address_id: ^address_id) |> Repo.one
      assert debit == nil
    end
  end
end
