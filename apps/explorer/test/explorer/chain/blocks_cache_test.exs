defmodule Explorer.Chain.BlocksCacheTest do
  use Explorer.DataCase

  alias Explorer.Chain.BlocksCache
  alias Explorer.Repo

  setup do
    Supervisor.terminate_child(Explorer.Supervisor, {ConCache, :blocks})
    Supervisor.restart_child(Explorer.Supervisor, {ConCache, :blocks})
    :ok
  end

  describe "update/1" do
    test "adds a new value to cache" do
      block = insert(:block) |> Repo.preload([:transactions, [miner: :names], :rewards])

      BlocksCache.update(block)

      assert BlocksCache.blocks() == [block]
    end

    test "adds a new elements removing the oldest one" do
      blocks =
        1..60
        |> Enum.map(fn number ->
          block = insert(:block, number: number)

          BlocksCache.update(block)

          block.number
        end)

      new_block = insert(:block, number: 70)
      BlocksCache.update(new_block)

      new_blocks = blocks |> List.replace_at(0, new_block.number) |> Enum.sort() |> Enum.reverse()

      assert Enum.map(BlocksCache.blocks(), & &1.number) == new_blocks
    end

    test "does not add too old blocks" do
      block = insert(:block, number: 100_000) |> Repo.preload([:transactions, [miner: :names], :rewards])
      old_block = insert(:block, number: 1_000)

      BlocksCache.update(block)
      BlocksCache.update(old_block)

      assert BlocksCache.blocks() == [block]
    end

    test "adds missing element" do
      block1 = insert(:block, number: 10)
      block2 = insert(:block, number: 4)

      BlocksCache.update(block1)
      BlocksCache.update(block2)

      assert Enum.count(BlocksCache.blocks()) == 2

      block3 = insert(:block, number: 6)

      BlocksCache.update(block3)

      assert Enum.map(BlocksCache.blocks(), & &1.number) == [10, 6, 4]
    end
  end

  describe "rewrite_cache/1" do
    test "updates cache" do
      block = insert(:block)

      BlocksCache.update(block)

      block1 = insert(:block) |> Repo.preload([:transactions, [miner: :names], :rewards])
      block2 = insert(:block) |> Repo.preload([:transactions, [miner: :names], :rewards])

      new_blocks = [block1, block2]

      BlocksCache.rewrite_cache(new_blocks)

      assert BlocksCache.blocks() == [block2, block1]
    end
  end
end
