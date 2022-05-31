defmodule Explorer.Chain.CeloPendingEpochOperationTest do
  use Explorer.DataCase

  import Explorer.Factory

  alias Explorer.{Chain, Repo}
  alias Chain.CeloPendingEpochOperation

  describe "falsify_celo_pending_epoch_operation/2" do
    test "sets fetch_epoch_rewards to false if validator group data is not yet indexed" do
      block = insert(:block)
      insert(:celo_pending_epoch_operations, block_number: block.number)

      CeloPendingEpochOperation.falsify_celo_pending_epoch_operation(block.number, :fetch_epoch_rewards)

      celo_pending_operation = Repo.get(CeloPendingEpochOperation, block.number)
      assert Map.fetch!(celo_pending_operation, :fetch_epoch_rewards) == false
    end
  end
end
