defmodule Explorer.SkippedBlocksTest do
  use Explorer.DataCase

  alias Explorer.Block
  alias Explorer.Repo
  alias Explorer.SkippedBlocks

  describe "fetch/0" do
    test "inserts a missing block into the database" do
      insert(:block, %{number: 2})
      use_cassette "skipped_block_fetch" do
        SkippedBlocks.fetch()

        blocks = Block |> order_by(asc: :number) |> Repo.all |> Enum.map(fn(block) -> block.number end)

        assert blocks == [1, 2]
      end
    end
  end

  describe "get_skipped_blocks/0 when there are no blocks" do
    test "returns no blocks" do
      assert SkippedBlocks.get_skipped_blocks() == []
    end
  end

  describe "get_skipped_blocks/0 when there are no skipped blocks" do
    test "returns no blocks" do
      insert(:block, %{number: 1})
      assert SkippedBlocks.get_skipped_blocks() == []
    end
  end

  describe "get_skipped_blocks/0 when a block has been skipped" do
    test "returns no blocks" do
      insert(:block, %{number: 2})
      assert SkippedBlocks.get_skipped_blocks() == [1]
    end
  end

  describe "get_last_block_number/0 when there are no blocks" do
    test "returns zero" do
      assert SkippedBlocks.get_last_block_number() == 0
    end
  end

  describe "get_last_block_number/0 when there is a block" do
    test "returns the number of the block" do
      insert(:block, %{number: 1})
      assert SkippedBlocks.get_last_block_number() == 1
    end
  end
end
