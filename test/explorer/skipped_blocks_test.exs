defmodule Explorer.SkippedBlocksTest do
  use Explorer.DataCase

  alias Explorer.SkippedBlocks

  describe "first/0 when there are no blocks" do
    test "returns no blocks" do
      assert SkippedBlocks.first() == []
    end
  end

  describe "first/0 when there are no skipped blocks" do
    test "returns no blocks" do
      insert(:block, %{number: 0})
      assert SkippedBlocks.first() == []
    end
  end

  describe "first/0 when a block has been skipped" do
    test "returns the first skipped block number" do
      insert(:block, %{number: 0})
      insert(:block, %{number: 2})
      assert SkippedBlocks.first() == ["1"]
    end
  end

  describe "first/1 when there are no blocks" do
    test "returns no blocks" do
      assert SkippedBlocks.first(1) == []
    end
  end

  describe "first/1 when there are no skipped blocks" do
    test "returns no blocks" do
      insert(:block, %{number: 0})
      assert SkippedBlocks.first(1) == []
    end
  end

  describe "first/1 when a block has been skipped" do
    test "returns the skipped block number" do
      insert(:block, %{number: 1})
      assert SkippedBlocks.first(1) == ["0"]
    end

    test "returns up to the requested number of skipped block numbers in reverse order" do
      insert(:block, %{number: 1})
      insert(:block, %{number: 3})
      assert SkippedBlocks.first(1) == ["2"]
    end

    test "returns only the skipped block number" do
      insert(:block, %{number: 1})
      assert SkippedBlocks.first(100) == ["0"]
    end

    test "returns all the skipped block numbers in descending order" do
      insert(:block, %{number: 1})
      insert(:block, %{number: 3})
      assert SkippedBlocks.first(100) == ["2", "0"]
    end
  end

  describe "latest_block_number/0 when there are no blocks" do
    test "returns -1" do
      assert SkippedBlocks.latest_block_number() == -1
    end
  end

  describe "latest_block_number/0 when there is a block" do
    test "returns the number of the block" do
      insert(:block, %{number: 1})
      assert SkippedBlocks.latest_block_number() == 1
    end
  end
end
