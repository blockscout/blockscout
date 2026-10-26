# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Chain.Import.Runner.LogsTest do
  use Explorer.DataCase

  alias Explorer.Chain
  alias Explorer.Chain.Log

  describe "run/3" do
    test "does not insert the logs of the blocks that are not consensus anymore" do
      consensus_block = insert(:block, consensus: true)
      non_consensus_block = insert(:block, consensus: false)
      transaction = :transaction |> insert() |> with_block(consensus_block)
      address = insert(:address)

      log_params = fn block ->
        %{
          address_hash: to_string(address.hash),
          block_hash: block.hash,
          block_number: block.number,
          data: "0x01",
          index: 0,
          transaction_hash: transaction.hash,
          transaction_index: 0
        }
      end

      assert {:ok, %{logs: [%Log{block_hash: block_hash}]}} =
               Chain.import(%{logs: %{params: [log_params.(consensus_block), log_params.(non_consensus_block)]}})

      assert block_hash == consensus_block.hash
      assert Repo.aggregate(Log, :count) == 1
    end
  end
end
