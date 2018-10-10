defmodule Explorer.Counters.BlockValidationCounterTest do
  use Explorer.DataCase

  alias Explorer.Counters.BlockValidationCounter

  describe "consolidate/0" do
    test "loads the address' validations consolidated info" do
      BlockValidationCounter.start_link([])

      address = insert(:address)

      insert(:block, miner: address, miner_hash: address.hash)
      insert(:block, miner: address, miner_hash: address.hash)

      another_address = insert(:address)

      insert(:block, miner: another_address, miner_hash: another_address.hash)

      BlockValidationCounter.consolidate_blocks()

      assert BlockValidationCounter.fetch(address.hash) == 2
      assert BlockValidationCounter.fetch(another_address.hash) == 1
    end
  end

  describe "fetch/1" do
    test "fetches the total block validations by a given address" do
      BlockValidationCounter.start_link([])

      address = insert(:address)
      another_address = insert(:address)

      assert BlockValidationCounter.fetch(address.hash) == 0
      assert BlockValidationCounter.fetch(another_address.hash) == 0

      BlockValidationCounter.insert_or_update_counter(address.hash, 1)
      BlockValidationCounter.insert_or_update_counter(another_address.hash, 10)

      assert BlockValidationCounter.fetch(address.hash) == 1
      assert BlockValidationCounter.fetch(another_address.hash) == 10
    end
  end
end
