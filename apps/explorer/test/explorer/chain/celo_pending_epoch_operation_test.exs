defmodule Explorer.Chain.CeloPendingEpochOperationTest do
  use Explorer.DataCase

  import Explorer.Factory

  alias Explorer.{Chain, Repo}
  alias Chain.CeloPendingEpochOperation

  describe "falsify_or_delete_celo_pending_epoch_operation/2" do
    test "sets fetch_epoch_rewards to false if validator group data is not yet indexed" do
      block = insert(:block)
      insert(:celo_pending_epoch_operations, block_hash: block.hash)

      CeloPendingEpochOperation.falsify_or_delete_celo_pending_epoch_operation(block.hash, :fetch_epoch_rewards)

      celo_pending_operation = Repo.get(CeloPendingEpochOperation, block.hash)
      assert Map.fetch!(celo_pending_operation, :fetch_epoch_rewards) == false
    end

    test "deletes an epoch block hash for which both epoch and validator group data have been indexed" do
      block = insert(:block)
      insert(:celo_pending_epoch_operations, block_hash: block.hash, fetch_epoch_rewards: false)

      CeloPendingEpochOperation.falsify_or_delete_celo_pending_epoch_operation(block.hash, :fetch_validator_group_data)

      assert Repo.one!(select(CeloPendingEpochOperation, fragment("COUNT(*)"))) == 0
    end
  end
end
