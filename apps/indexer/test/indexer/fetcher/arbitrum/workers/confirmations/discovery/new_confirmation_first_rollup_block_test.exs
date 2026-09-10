# SPDX-License-Identifier: LicenseRef-Blockscout
if Application.get_env(:explorer, :chain_type) == :arbitrum do
  defmodule Indexer.Fetcher.Arbitrum.Workers.Confirmations.Discovery.NewConfirmationFirstRollupBlockTest do
    use Indexer.Fetcher.Arbitrum.Workers.Confirmations.Discovery.TestCase

    # See `Indexer.Fetcher.Arbitrum.Workers.Confirmations.Discovery.TestCase` for
    # the conventions this suite of files follows.

    # The arguments of the run give the lowest indexed block of the chain. The walk
    # of a confirmation cannot move below that block. The discovery does not look
    # for a batch below it.
    #
    # This group holds two reasons for the stop: the block is the first rollup
    # block of the run, or no block is below it.
    describe "perform/5 with a new confirmation and a configured first rollup block" do
      # The database has one batch with the rollup blocks 100..110, and no block of it
      # is confirmed. The database holds no block below 100. The configuration of the
      # indexer can start the rollup blocks above the genesis, and then the database
      # has this state.
      #
      # The event points to the rollup block 110. The lookup finds no earlier
      # confirmation, and the batch is complete. Thus the discovery reaches the block
      # 100, which is the first rollup block of the run. It stops there, and it does
      # not look for a batch below. The result is `:ok`, and the confirmation covers
      # the blocks 100..110.
      #
      # With the value 1, the discovery stops at the block 1 for two reasons. The block
      # is the first rollup block, and no block is below it. This test holds the first
      # reason only. The test "stops at the block 1 when the run starts at the block
      # 0" holds the second reason only.
      test "stops at the first rollup block of the run when that block is above 1", %{
        json_rpc_named_arguments: json_rpc_named_arguments
      } do
        batch = seed_batch(100, 110, @commitment_l1_block)

        confirmation_transaction_hash = to_string(transaction_hash())

        expect_discovery(rollup_block_hash(batch, 110), confirmation_transaction_hash)

        assert :ok == discover(json_rpc_named_arguments, @logs_block_range, 100)

        confirmation = Repo.get_by!(LifecycleTransaction, hash: confirmation_transaction_hash)
        assert confirmed_blocks(confirmation) == Enum.to_list(100..110)
        assert unconfirmed_blocks() == []
      end

      # The database has one batch with the rollup blocks 1..10, and no block of it
      # is confirmed. The run starts at the rollup block 0. This is the default
      # configuration of the indexer. The block 0 is the genesis of the rollup, and
      # no batch holds that block.
      #
      # The event points to the rollup block 10. The lookup finds no earlier
      # confirmation, and the batch is complete. Thus the discovery reaches the block
      # 1. That block is above the first rollup block of the run, but no block is
      # below it. Thus the discovery stops there, and it does not look for a batch
      # below. The result is `:ok`, and the confirmation covers the blocks 1..10.
      #
      # This test holds the second reason for the stop at the block 1 only. The test
      # "stops at the first rollup block of the run when that block is above 1" holds
      # the first reason only.
      test "stops at the block 1 when the run starts at the block 0", %{
        json_rpc_named_arguments: json_rpc_named_arguments
      } do
        batch = seed_batch(1, 10, @commitment_l1_block)

        confirmation_transaction_hash = to_string(transaction_hash())

        expect_discovery(rollup_block_hash(batch, 10), confirmation_transaction_hash)

        assert :ok == discover(json_rpc_named_arguments, @logs_block_range, 0)

        confirmation = Repo.get_by!(LifecycleTransaction, hash: confirmation_transaction_hash)
        assert confirmed_blocks(confirmation) == Enum.to_list(1..10)
        assert unconfirmed_blocks() == []
      end
    end
  end
end
