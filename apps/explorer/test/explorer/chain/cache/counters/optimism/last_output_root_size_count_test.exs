defmodule Explorer.Chain.Cache.Counters.Optimism.LastOutputRootSizeCountTest do
  use Explorer.DataCase

  alias Explorer.Chain.Cache.Counters.Optimism.LastOutputRootSizeCount

  if Application.compile_env(:explorer, :chain_type) == :optimism do
    test "populates the cache with the number of transactions in last output root" do
      first_block = insert(:block)

      insert(:op_output_root, l2_block_number: first_block.number)

      second_block = insert(:block, number: first_block.number + 10)
      insert(:op_output_root, l2_block_number: second_block.number)

      insert(:transaction) |> with_block(first_block)
      insert(:transaction) |> with_block(second_block)
      insert(:transaction) |> with_block(second_block)

      start_supervised!(LastOutputRootSizeCount)
      LastOutputRootSizeCount.consolidate()

      assert LastOutputRootSizeCount.fetch([]) == Decimal.new("2")
    end

    test "does not count transactions that are not in output root yet" do
      first_block = insert(:block)

      insert(:op_output_root, l2_block_number: first_block.number)

      second_block = insert(:block, number: first_block.number + 10)
      insert(:op_output_root, l2_block_number: second_block.number)

      insert(:transaction) |> with_block(first_block)
      insert(:transaction) |> with_block(second_block)
      insert(:transaction) |> with_block(second_block)

      third_block = insert(:block, number: second_block.number + 1)
      insert(:transaction) |> with_block(third_block)
      insert(:transaction) |> with_block(third_block)

      start_supervised!(LastOutputRootSizeCount)
      LastOutputRootSizeCount.consolidate()

      assert LastOutputRootSizeCount.fetch([]) == Decimal.new("2")
    end
  end
end
