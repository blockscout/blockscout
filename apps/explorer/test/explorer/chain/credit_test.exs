defmodule Explorer.Chain.CreditTest do
  use Explorer.DataCase

  alias Explorer.Chain.Credit

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
      recipient = insert(:address)
      sender = insert(:address)
      transaction = insert(:transaction, to_address_hash: recipient.hash, from_address_hash: sender.hash)
      insert(:receipt, transaction: transaction, status: 1)
      Credit.refresh()
      credits = Credit |> Repo.all()
      assert credits |> Enum.count() == 1
    end

    test "returns no credits to the sender" do
      recipient = insert(:address)
      sender = insert(:address)

      transaction = insert(:transaction, value: 21, to_address_hash: recipient.hash, from_address_hash: sender.hash)

      insert(:receipt, transaction: transaction, status: 1)
      address_hash = sender.hash
      Credit.refresh()
      credit = Credit |> where(address_hash: ^address_hash) |> Repo.one()
      assert credit == nil
    end

    test "returns a credit to the recipient" do
      recipient = insert(:address)
      sender = insert(:address)

      transaction = insert(:transaction, value: 21, to_address_hash: recipient.hash, from_address_hash: sender.hash)

      insert(:receipt, transaction: transaction, status: 1)
      address_hash = recipient.hash
      Credit.refresh()
      credit = Credit |> where(address_hash: ^address_hash) |> Repo.one()
      assert credit.value == Decimal.new(21)
    end
  end
end
