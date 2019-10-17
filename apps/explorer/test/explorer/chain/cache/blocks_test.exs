defmodule Explorer.Chain.Cache.BlocksTest do
  use Explorer.DataCase

  alias Explorer.Chain.Cache.Blocks
  alias Explorer.Repo

  setup do
    Supervisor.terminate_child(Explorer.Supervisor, Blocks.child_id())
    Supervisor.restart_child(Explorer.Supervisor, Blocks.child_id())
    :ok
  end

  describe "update/1" do
    test "adds a new value to cache" do
      block = insert(:block) |> Repo.preload([:transactions, [miner: :names], :rewards])

      Blocks.update(block)

      assert Blocks.all() == [block]
    end

    test "adds a new elements removing the oldest one" do
      blocks =
        1..60
        |> Enum.map(fn number ->
          block = insert(:block, number: number)

          Blocks.update(block)

          block.number
        end)

      assert Blocks.size() == 60

      new_block = insert(:block, number: 70)
      Blocks.update(new_block)

      new_blocks = blocks |> List.replace_at(0, new_block.number) |> Enum.sort() |> Enum.reverse()

      assert Blocks.full?()

      assert Enum.map(Blocks.all(), & &1.number) == new_blocks
    end

    test "adds missing element" do
      block1 = insert(:block, number: 10)
      block2 = insert(:block, number: 4)

      Blocks.update(block1)
      Blocks.update(block2)

      assert Blocks.size() == 2

      block3 = insert(:block, number: 6)

      Blocks.update(block3)

      assert Enum.map(Blocks.all(), & &1.number) == [10, 6, 4]
    end
  end
end
