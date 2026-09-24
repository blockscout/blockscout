# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Chain.Arbitrum.Reader.Indexer.GeneralTest do
  use Explorer.DataCase

  alias Explorer.Chain.Arbitrum.Reader.Indexer.General, as: ArbitrumGeneralReader

  describe "rollup_blocks/2" do
    test "returns empty list when given an empty list of block numbers" do
      assert ArbitrumGeneralReader.rollup_blocks([]) == []
      assert ArbitrumGeneralReader.rollup_blocks([], 10) == []
    end

    test "retrieves blocks when count is within a single chunk" do
      _b1 = insert(:block, number: 100)
      _b2 = insert(:block, number: 101)

      result = ArbitrumGeneralReader.rollup_blocks([100, 101], 500)
      result_numbers = Enum.map(result, & &1.number) |> Enum.sort()

      assert result_numbers == [100, 101]
    end

    test "chunks queries and combines results when block list exceeds chunk_size" do
      _b1 = insert(:block, number: 200)
      _b2 = insert(:block, number: 201)
      _b3 = insert(:block, number: 202)
      _b4 = insert(:block, number: 203)
      _b5 = insert(:block, number: 204)

      # Using chunk_size of 2 with 5 blocks forces 3 database query chunks
      result = ArbitrumGeneralReader.rollup_blocks([200, 201, 202, 203, 204], 2)
      result_numbers = Enum.map(result, & &1.number) |> Enum.sort()

      assert result_numbers == [200, 201, 202, 203, 204]
    end

    test "correctly preloads transaction associations across multiple chunks" do
      block1 = insert(:block, number: 300)
      block2 = insert(:block, number: 301)
      tx1 = insert(:transaction, block: block1, block_number: block1.number)
      tx2 = insert(:transaction, block: block2, block_number: block2.number)

      result = ArbitrumGeneralReader.rollup_blocks([300, 301], 1)
      assert length(result) == 2

      result_map = Map.new(result, fn b -> {b.number, b} end)
      assert length(result_map[300].transactions) == 1
      assert hd(result_map[300].transactions).hash == tx1.hash
      assert length(result_map[301].transactions) == 1
      assert hd(result_map[301].transactions).hash == tx2.hash
    end

    test "ignores block numbers that do not exist in the database" do
      _b1 = insert(:block, number: 400)

      result = ArbitrumGeneralReader.rollup_blocks([400, 401, 402, 403], 2)
      result_numbers = Enum.map(result, & &1.number)

      assert result_numbers == [400]
    end

    test "deduplicates repeated block numbers across separate chunks" do
      _b1 = insert(:block, number: 500)
      _b2 = insert(:block, number: 501)

      # [500, 501, 500] with chunk_size 2 would span 2 chunks; deduplication ensures block 500 is only returned once
      result = ArbitrumGeneralReader.rollup_blocks([500, 501, 500], 2)
      result_numbers = Enum.map(result, & &1.number)

      assert result_numbers == [500, 501]
    end
  end
end
