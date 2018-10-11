defmodule Explorer.Counters.TransactionCounterTest do
  use Explorer.DataCase

  alias Explorer.Counters.TransactionCounter

  describe "consolidate/0" do
    test "loads transactions consolidate info" do
      address_a = insert(:address)
      address_b = insert(:address)

      :transaction
      |> insert(to_address: address_a, from_address: address_b)
      |> with_block()

      TransactionCounter.consolidate()

      assert TransactionCounter.fetch(address_a.hash) == 1
      assert TransactionCounter.fetch(address_b.hash) == 1
    end
  end

  describe "fetch/1" do
    test "fetchs the total transactions by address hash" do
      address = insert(:address)

      assert TransactionCounter.fetch(address.hash) == 0

      TransactionCounter.insert_or_update_counter(address.hash, 15)

      assert TransactionCounter.fetch(address.hash) == 15
    end
  end

  describe "prepare_transactions/0" do
    test "returns an array so that each item is a tuple with the address and the transactions number" do
      address_a = insert(:address)
      address_b = insert(:address)
      address_c = insert(:contract_address)
      transaction_a = insert(:transaction, from_address: address_a, to_address: address_b)
      transaction_b = insert(:transaction, from_address: address_b, to_address: address_a)

      transaction_c =
        insert(:transaction, from_address: address_a, created_contract_address: address_c, to_address: nil)

      transactions = [
        transaction_a,
        transaction_b,
        transaction_c
      ]

      expected = [
        {address_a.hash, 3},
        {address_b.hash, 2},
        {address_c.hash, 1}
      ]

      assert TransactionCounter.prepare_transactions(transactions) == expected
    end
  end
end
