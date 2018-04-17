defmodule Explorer.Chain.DebitTest do
  use Explorer.DataCase

  alias Explorer.Chain.Debit

  describe "Repo.all/1" do
    test "returns no rows when there are no addresses" do
      assert Repo.all(Debit) == []
    end

    test "returns nothing when an address has no transactions" do
      insert(:address)
      Debit.refresh()
      assert Repo.one(Debit) == nil
    end

    test "returns a debit when there is an address with a receipt" do
      recipient = insert(:address)
      sender = insert(:address)
      transaction = insert(:transaction, to_address_id: recipient.id, from_address_id: sender.id)
      insert(:receipt, transaction: transaction, status: 1)
      Debit.refresh()
      debits = Debit |> Repo.all()
      assert debits |> Enum.count() == 1
    end

    test "returns a debit against the sender" do
      recipient = insert(:address)
      sender = insert(:address)

      transaction = insert(:transaction, value: 21, to_address_id: recipient.id, from_address_id: sender.id)

      insert(:receipt, transaction: transaction, status: 1)
      address_id = sender.id
      Debit.refresh()
      debit = Debit |> where(address_id: ^address_id) |> Repo.one()
      assert debit.value == Decimal.new(21)
    end

    test "returns no debits against the recipient" do
      recipient = insert(:address)
      sender = insert(:address)

      transaction = insert(:transaction, value: 21, to_address_id: recipient.id, from_address_id: sender.id)

      insert(:receipt, transaction: transaction, status: 1)
      address_id = recipient.id
      Debit.refresh()
      debit = Debit |> where(address_id: ^address_id) |> Repo.one()
      assert debit == nil
    end
  end
end
