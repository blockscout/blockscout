# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Chain.Import.Runner.HelperTest do
  use Explorer.DataCase

  alias Explorer.Chain.Import.Runner.Helper

  @options %{timeout: :timer.seconds(5)}

  describe "reject_changes_of_non_consensus_blocks/4" do
    test "drops only the changes of the stored non-consensus blocks" do
      consensus_block = insert(:block, consensus: true)
      non_consensus_block = insert(:block, consensus: false)

      consensus_block_change = %{block_hash: consensus_block.hash, block_number: consensus_block.number, index: 0}

      non_consensus_block_change = %{
        block_hash: non_consensus_block.hash,
        block_number: non_consensus_block.number,
        index: 1
      }

      unknown_block_change = %{block_hash: block_hash(), block_number: 1, index: 2}
      change_without_block = %{block_hash: nil, index: 3}

      changes_list = [consensus_block_change, non_consensus_block_change, unknown_block_change, change_without_block]

      assert Helper.reject_changes_of_non_consensus_blocks(Repo, changes_list, @options, "changes") == [
               consensus_block_change,
               unknown_block_change,
               change_without_block
             ]
    end

    test "returns the changes as is when none of them has a block hash" do
      changes_list = [%{index: 0}, %{block_hash: nil, index: 1}]

      assert Helper.reject_changes_of_non_consensus_blocks(Repo, changes_list, @options, "changes") == changes_list
    end
  end
end
