defmodule Explorer.Counters.TransactionCounterTest do
  use Explorer.DataCase

  alias Explorer.Counters.TransactionCounter

  setup do
    TransactionCounter.create_table()
    :ok
  end

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
end
