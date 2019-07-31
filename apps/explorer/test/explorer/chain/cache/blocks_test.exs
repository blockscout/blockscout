defmodule Explorer.Chain.Cache.BlocksTest do
  use Explorer.DataCase

  alias Explorer.Chain.Cache.Blocks
  alias Explorer.Repo

  setup do
    Supervisor.terminate_child(Explorer.Supervisor, {ConCache, :blocks})
    Supervisor.restart_child(Explorer.Supervisor, {ConCache, :blocks})
    :ok
  end

  describe "update/1" do
    test "adds a new value to cache" do
      block = insert(:block) |> Repo.preload([:transactions, [miner: :names], :rewards])

      Blocks.update(block)

      assert Blocks.blocks() == [block]
    end

    test "adds a new elements removing the oldest one" do
      blocks =
        1..60
        |> Enum.map(fn number ->
          block = insert(:block, number: number)

          Blocks.update(block)

          block.number
        end)

      new_block = insert(:block, number: 70)
      Blocks.update(new_block)

      new_blocks = blocks |> List.replace_at(0, new_block.number) |> Enum.sort() |> Enum.reverse()

      assert Enum.map(Blocks.blocks(), & &1.number) == new_blocks
    end

    test "does not add too old blocks" do
      block = insert(:block, number: 100_000) |> Repo.preload([:transactions, [miner: :names], :rewards])
      old_block = insert(:block, number: 1_000)

      Blocks.update(block)
      Blocks.update(old_block)

      assert Blocks.blocks() == [block]
    end

    test "adds missing element" do
      block1 = insert(:block, number: 10)
      block2 = insert(:block, number: 4)

      Blocks.update(block1)
      Blocks.update(block2)

      assert Enum.count(Blocks.blocks()) == 2

      block3 = insert(:block, number: 6)

      Blocks.update(block3)

      assert Enum.map(Blocks.blocks(), & &1.number) == [10, 6, 4]
    end
  end

  describe "rewrite_cache/1" do
    test "updates cache" do
      block = insert(:block)

      Blocks.update(block)

      block1 = insert(:block) |> Repo.preload([:transactions, [miner: :names], :rewards])
      block2 = insert(:block) |> Repo.preload([:transactions, [miner: :names], :rewards])

      new_blocks = [block1, block2]

      Blocks.rewrite_cache(new_blocks)

      assert Blocks.blocks() == [block2, block1]
    end
  end
end
