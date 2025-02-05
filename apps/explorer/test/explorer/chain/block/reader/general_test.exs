defmodule Explorer.Chain.Block.Reader.GeneralTest do
  use Explorer.DataCase

  alias Explorer.Chain.Block.Reader.General, as: BlockGeneralReader

  describe "timestamp_to_block_number/4" do
    test "returns correct block number when given timestamp is equal to block timestamp" do
      timestamp = DateTime.from_unix!(60 * 60 * 24 * 1, :second)
      block = insert(:block, timestamp: timestamp)
      expected = {:ok, block.number}

      assert ^expected = BlockGeneralReader.timestamp_to_block_number(timestamp, :after, true, false)
      assert ^expected = BlockGeneralReader.timestamp_to_block_number(timestamp, :before, true, false)
    end

    test "with strict=true returns block after timestamp" do
      timestamp = DateTime.from_unix!(60 * 60 * 24 * 1, :second)

      # Insert blocks before and after the timestamp
      before_block = insert(:block, timestamp: DateTime.add(timestamp, -10, :second))
      target_block = insert(:block, timestamp: DateTime.add(timestamp, 5, :second))
      _after_block = insert(:block, timestamp: DateTime.add(timestamp, 20, :second))

      # When searching for blocks after the timestamp
      expected = {:ok, target_block.number}
      assert ^expected = BlockGeneralReader.timestamp_to_block_number(timestamp, :after, true, true)

      # When searching for blocks before the timestamp
      expected = {:ok, before_block.number}
      assert ^expected = BlockGeneralReader.timestamp_to_block_number(timestamp, :before, true, true)
    end

    test "with strict=true returns error when no blocks found" do
      timestamp = DateTime.from_unix!(60 * 60 * 24 * 1, :second)

      # Insert blocks only after the timestamp
      _after_block = insert(:block, timestamp: DateTime.add(timestamp, 10, :second))

      # When searching for blocks before the timestamp
      assert {:error, :not_found} = BlockGeneralReader.timestamp_to_block_number(timestamp, :before, true, true)

      # Clear blocks and insert one before
      Repo.delete_all(Explorer.Chain.Block)
      _before_block = insert(:block, timestamp: DateTime.add(timestamp, -10, :second))

      # When searching for blocks after the timestamp
      assert {:error, :not_found} = BlockGeneralReader.timestamp_to_block_number(timestamp, :after, true, true)
    end
  end
end
