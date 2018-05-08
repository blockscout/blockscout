defmodule Explorer.Chain.DebitTest do
  use Explorer.DataCase

  alias Explorer.Chain.{Debit, Wei}

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
      block = insert(:block)

      transaction =
        insert(
          :transaction,
          block_hash: block.hash,
          index: 0,
          to_address_hash: recipient.hash,
          from_address_hash: sender.hash
        )

      insert(:receipt, transaction_hash: transaction.hash, transaction_index: transaction.index, status: :ok)
      Debit.refresh()
      debits = Debit |> Repo.all()
      assert debits |> Enum.count() == 1
    end

    test "returns a debit against the sender" do
      recipient = insert(:address)
      sender = insert(:address)

      block = insert(:block)

      transaction =
        insert(
          :transaction,
          block_hash: block.hash,
          index: 0,
          value: 21,
          to_address_hash: recipient.hash,
          from_address_hash: sender.hash
        )

      insert(:receipt, transaction_hash: transaction.hash, transaction_index: transaction.index, status: :ok)
      address_hash = sender.hash
      Debit.refresh()
      debit = Debit |> where(address_hash: ^address_hash) |> Repo.one()
      assert debit.value == %Wei{value: Decimal.new(21)}
    end

    test "returns no debits against the recipient" do
      recipient = insert(:address)
      sender = insert(:address)
      block = insert(:block)

      transaction =
        insert(
          :transaction,
          block_hash: block.hash,
          index: 0,
          value: 21,
          to_address_hash: recipient.hash,
          from_address_hash: sender.hash
        )

      insert(:receipt, transaction_hash: transaction.hash, transaction_index: transaction.index, status: :ok)
      address_hash = recipient.hash
      Debit.refresh()
      debit = Debit |> where(address_hash: ^address_hash) |> Repo.one()
      assert debit == nil
    end
  end
end
