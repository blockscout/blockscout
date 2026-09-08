# SPDX-License-Identifier: LicenseRef-Blockscout
if Application.get_env(:explorer, :chain_type) == :arbitrum do
  defmodule Indexer.Fetcher.Arbitrum.Workers.Confirmations.Discovery.NewConfirmationIncompleteDatabaseTest do
    use Indexer.Fetcher.Arbitrum.Workers.Confirmations.Discovery.TestCase

    # See `Indexer.Fetcher.Arbitrum.Workers.Confirmations.Discovery.TestCase` for
    # the conventions this suite of files follows.

    # The database can hold a part of the data which a confirmation needs. The
    # indexer writes a batch, the links of its rollup blocks and the blocks
    # themselves in several steps, and the discovery can read the parent chain
    # between those steps.
    #
    # This group holds one scenario per shape of the missing data. Most of them
    # postpone the confirmation with the result `:confirmation_missed`, which sends
    # the parent chain range to the historical discovery. Two of them show the
    # opposite: the missing data is outside the range of the confirmation, thus the
    # discovery writes that confirmation.
    #
    # Each test of a postponement has two parts. The first part gives
    # `:confirmation_missed` for the state of the database. The second part makes the
    # change of the indexer, and it examines the same parent chain range again.
    describe "perform/5 with a new confirmation and an incomplete database" do
      # The database has one batch of the blocks 1..10. No block of it is confirmed.
      # The block 10 is not linked to the batch. If the indexer did not handle the
      # whole batch, the database has this state.
      #
      # The event points to the rollup block 10. That block holds no link to the batch.
      #
      # The discovery finds the number of a rollup block through the batch of that
      # block. Thus it cannot find the number of the block 10, and it drops the event.
      # After that step no event of the range holds a rollup block number. Therefore
      # the discovery does not start the lookup of an earlier confirmation, and it does
      # not start the walk to the batch below. It writes nothing, and it returns
      # `:confirmation_missed`.
      #
      # This test holds the shortest run of this suite: the discovery reads the logs of
      # the range and stops.
      #
      # The second part of the test makes the change of the indexer: the indexer links
      # the block 10 to the batch. Then the discovery examines the same parent chain
      # range again, and the confirmation covers the full batch.
      test "postpones the confirmation when the confirmed block is not linked to its batch", %{
        json_rpc_named_arguments: json_rpc_named_arguments
      } do
        batch = seed_batch(@rollup_first_block, 10, @commitment_l1_block, unlinked_blocks: [10])

        confirmation_transaction_hash = to_string(transaction_hash())

        expect_discovery(rollup_block_hash(batch, 10), confirmation_transaction_hash)

        assert :confirmation_missed == discover(json_rpc_named_arguments)

        assert Repo.get_by(LifecycleTransaction, hash: confirmation_transaction_hash) == nil

        assert unconfirmed_blocks() == Enum.to_list(@rollup_first_block..9)

        link_blocks_to_batch(batch, [10])

        assert :ok == discover(json_rpc_named_arguments)

        confirmation = Repo.get_by!(LifecycleTransaction, hash: confirmation_transaction_hash)
        assert confirmed_blocks(confirmation) == Enum.to_list(@rollup_first_block..10)
        assert unconfirmed_blocks() == []
      end

      # The database has one batch of the blocks 1..10. The blocks 1..9 and their
      # links to the batch are in the database. The rollup block 10 is not in the
      # database at all: the block fetcher did not reach it yet.
      #
      # The event points to the rollup block 10 by its hash. The discovery finds the
      # number of a rollup block through the batch of that block. The block 10 is not
      # in the database, thus the discovery cannot find its number, and it drops the
      # event. After that step no event of the range holds a rollup block number.
      # Therefore the discovery writes nothing, and it returns `:confirmation_missed`.
      #
      # This test is not redundant. The test "postpones the confirmation when the
      # confirmed block is not linked to its batch" gives the same run of the
      # discovery, because the lookup of the number joins the blocks with the links to
      # the batches. But the state of the database is another one, and the change of
      # the indexer is another one: there the indexer writes the missing link, and here
      # the block fetcher writes the block itself. This test is the only one where the
      # event points to a rollup block which the database does not hold.
      #
      # The second part of the test makes the change of the block fetcher and the
      # indexer: they write the block 10 with the hash of the event and the link of
      # that block to its batch. Then the discovery examines the same parent chain
      # range again, and the confirmation covers the full batch.
      test "postpones the confirmation when the confirmed block is not indexed yet", %{
        json_rpc_named_arguments: json_rpc_named_arguments
      } do
        batch = seed_batch(@rollup_first_block, 10, @commitment_l1_block, absent_blocks: [10])

        # The block fetcher writes this block in the second part of the test. Thus the
        # event of the first part points to a hash which the database does not hold.
        absent_rollup_block_hash = block_hash()

        confirmation_transaction_hash = to_string(transaction_hash())

        expect_discovery(to_string(absent_rollup_block_hash), confirmation_transaction_hash)

        assert :confirmation_missed == discover(json_rpc_named_arguments)

        assert Repo.get_by(LifecycleTransaction, hash: confirmation_transaction_hash) == nil
        assert unconfirmed_blocks() == Enum.to_list(@rollup_first_block..9)

        insert_block_and_link_to_batch(batch, 10, absent_rollup_block_hash)

        assert :ok == discover(json_rpc_named_arguments)

        confirmation = Repo.get_by!(LifecycleTransaction, hash: confirmation_transaction_hash)
        assert confirmed_blocks(confirmation) == Enum.to_list(@rollup_first_block..10)
        assert unconfirmed_blocks() == []
      end

      # The database has one batch of the blocks 1..10, but only the block 10 is
      # linked to that batch. The block 10 also holds a link to a confirmation of an
      # earlier run. This pair of states shows an inconsistency of the database. A run
      # which confirms the block 10 needs the links of the blocks below it. The
      # discovery must not write a confirmation from such a state.
      #
      # The event points to the rollup block 10.
      #
      # The batch holds no unconfirmed block. The number of its confirmed blocks is
      # 1, and the batch has 10 blocks. Such a batch is not complete, and the
      # discovery does not use it. Thus the discovery writes nothing, and it returns
      # `:confirmation_missed`.
      #
      # The second part of the test makes the change of the indexer: the indexer
      # links the other blocks to the batch. Then the discovery examines the same
      # parent chain range again. The parent chain holds the confirmation of the
      # block 10 in the block 200, and the event gives that state. Thus the new
      # confirmation takes the block 10 from the link of the earlier run, and it
      # covers the full batch.
      test "postpones the confirmation when the batch is linked to a part of its blocks only", %{
        json_rpc_named_arguments: json_rpc_named_arguments
      } do
        batch = seed_batch(@rollup_first_block, 10, @commitment_l1_block, unlinked_blocks: @rollup_first_block..9)

        earlier_confirmation = insert_confirmation(@earlier_confirmation_l1_block)
        mark_confirmed([10], earlier_confirmation)

        confirmation_transaction_hash = to_string(transaction_hash())

        expect_discovery(rollup_block_hash(batch, 10), confirmation_transaction_hash)

        assert :confirmation_missed == discover(json_rpc_named_arguments)

        assert Repo.get_by(LifecycleTransaction, hash: confirmation_transaction_hash) == nil

        assert confirmed_blocks(earlier_confirmation) == [10]
        assert unconfirmed_blocks() == []

        link_blocks_to_batch(batch, @rollup_first_block..9)

        assert :ok == discover(json_rpc_named_arguments)

        confirmation = Repo.get_by!(LifecycleTransaction, hash: confirmation_transaction_hash)
        assert confirmed_blocks(confirmation) == Enum.to_list(@rollup_first_block..10)
        assert confirmed_blocks(earlier_confirmation) == []
        assert unconfirmed_blocks() == []
      end

      # The database has one batch of the blocks 1..10. No block of it is confirmed.
      # The block 5 is not linked to the batch. If the indexer did not handle the
      # whole batch, the database has this state.
      #
      # The event points to the rollup block 10.
      #
      # There is a gap between the blocks 4 and 6 in the unconfirmed blocks of the
      # batch. A gap shows that the database does not have the whole batch. Thus the
      # discovery writes nothing, and it returns `:confirmation_missed`.
      #
      # The second part of the test makes the change of the indexer: the indexer
      # links the block 5 to the batch. Then the discovery examines the same parent
      # chain range again, and the confirmation covers the full batch.
      test "postpones the confirmation when the blocks of the batch hold a gap", %{
        json_rpc_named_arguments: json_rpc_named_arguments
      } do
        batch = seed_batch(@rollup_first_block, 10, @commitment_l1_block, unlinked_blocks: [5])

        confirmation_transaction_hash = to_string(transaction_hash())

        expect_discovery(rollup_block_hash(batch, 10), confirmation_transaction_hash)

        assert :confirmation_missed == discover(json_rpc_named_arguments)

        assert Repo.get_by(LifecycleTransaction, hash: confirmation_transaction_hash) == nil

        assert unconfirmed_blocks() == Enum.to_list(@rollup_first_block..4) ++ Enum.to_list(6..10)

        link_blocks_to_batch(batch, [5])

        assert :ok == discover(json_rpc_named_arguments)

        confirmation = Repo.get_by!(LifecycleTransaction, hash: confirmation_transaction_hash)
        assert confirmed_blocks(confirmation) == Enum.to_list(@rollup_first_block..10)
        assert unconfirmed_blocks() == []
      end

      # The database has one batch of the blocks 1..10. No block of it is confirmed.
      # The block 1, which is the first block of the batch, is not linked to it. If the
      # indexer did not handle the whole batch, the database has this state.
      #
      # The event points to the rollup block 10.
      #
      # The unconfirmed blocks of the batch are the blocks 2..10. They hold no gap.
      # Their count is 9, and the range 1..10 holds 10 blocks. The discovery reads this
      # difference as an incomplete batch. Thus it writes nothing, and it returns
      # `:confirmation_missed`.
      #
      # This test is not redundant. The test "postpones the confirmation when the last
      # block of the batch below is not linked" fails the same check of the count. In
      # that test the incomplete batch is the batch below the event, and the discovery
      # drops the blocks of two batches. This test is the only one where the count of
      # the batch of the event itself is short.
      #
      # The second part of the test makes the change of the indexer: the indexer links
      # the block 1 to its batch. Then the discovery examines the same parent chain
      # range again, and the confirmation covers the full batch.
      test "postpones the confirmation when the first block of the batch is not linked", %{
        json_rpc_named_arguments: json_rpc_named_arguments
      } do
        batch = seed_batch(@rollup_first_block, 10, @commitment_l1_block, unlinked_blocks: [@rollup_first_block])

        confirmation_transaction_hash = to_string(transaction_hash())

        expect_discovery(rollup_block_hash(batch, 10), confirmation_transaction_hash)

        assert :confirmation_missed == discover(json_rpc_named_arguments)

        assert Repo.get_by(LifecycleTransaction, hash: confirmation_transaction_hash) == nil
        assert unconfirmed_blocks() == Enum.to_list(2..10)

        link_blocks_to_batch(batch, [@rollup_first_block])

        assert :ok == discover(json_rpc_named_arguments)

        confirmation = Repo.get_by!(LifecycleTransaction, hash: confirmation_transaction_hash)
        assert confirmed_blocks(confirmation) == Enum.to_list(@rollup_first_block..10)
        assert unconfirmed_blocks() == []
      end

      # The database has two batches: the blocks 1..10 and the blocks 11..20. No
      # block is confirmed. The block 10 is not linked to its batch. If the indexer
      # did not handle the whole first batch, the database has this state.
      #
      # The event points to the rollup block 20.
      #
      # The parent chain range of the second batch holds no other event. Thus the
      # confirmation covers the whole second batch, and the walk moves to the block
      # 10. The discovery finds the batch of that block through the range of the
      # batch, thus the missing link does not stop the walk.
      #
      # The unconfirmed blocks of the first batch are the blocks 1..9. They hold no
      # gap. Their count is 9, and the range 1..10 holds 10 blocks. The discovery
      # reads this difference as an incomplete batch. Thus it drops the blocks of the
      # first batch, and it drops the blocks 11..20 with them. It writes nothing, and
      # it returns `:confirmation_missed`.
      #
      # This test is not redundant. The test "postpones the confirmation when the
      # blocks of the batch hold a gap" finds a gap between two blocks. This test
      # finds no gap, because the missing block is the last block of the range.
      # The discovery makes these two checks one after another, and this test is the
      # only one which fails the second check.
      #
      # The second part of the test makes the change of the indexer: the indexer
      # links the block 10 to its batch. Then the discovery examines the same parent
      # chain range again, and the confirmation covers the two batches.
      test "postpones the confirmation when the last block of the batch below is not linked", %{
        json_rpc_named_arguments: json_rpc_named_arguments
      } do
        previous_batch = seed_batch(@rollup_first_block, 10, @previous_commitment_l1_block, unlinked_blocks: [10])
        batch = seed_batch(11, 20, @commitment_l1_block)

        confirmation_transaction_hash = to_string(transaction_hash())

        expect_discovery(rollup_block_hash(batch, 20), confirmation_transaction_hash)

        assert :confirmation_missed == discover(json_rpc_named_arguments)

        assert Repo.get_by(LifecycleTransaction, hash: confirmation_transaction_hash) == nil

        assert unconfirmed_blocks() == Enum.to_list(@rollup_first_block..9) ++ Enum.to_list(11..20)

        link_blocks_to_batch(previous_batch, [10])

        assert :ok == discover(json_rpc_named_arguments)

        confirmation = Repo.get_by!(LifecycleTransaction, hash: confirmation_transaction_hash)
        assert confirmed_blocks(confirmation) == Enum.to_list(@rollup_first_block..20)
        assert unconfirmed_blocks() == []
      end

      # The database has one batch of the blocks 11..20. No block of it is confirmed.
      # The batch below it is not in the database. If the discovery of the missing
      # batches did not reach that batch, the database has this state.
      #
      # The event points to the rollup block 20.
      #
      # The parent chain range of the batch holds no other event. Thus the
      # confirmation covers the whole batch, and the walk moves to the block 10. No
      # batch of the database holds that block. Therefore the discovery drops the
      # blocks of the batch 11..20 as well. It writes nothing, and it returns
      # `:confirmation_missed`.
      #
      # The second part of the test makes the change of the indexer: the indexer
      # writes the batch below. Then the discovery examines the same parent chain
      # range again, and the confirmation covers the two batches.
      test "postpones the confirmation when the batch below the current one is missing", %{
        json_rpc_named_arguments: json_rpc_named_arguments
      } do
        batch = seed_batch(11, 20, @commitment_l1_block)

        confirmation_transaction_hash = to_string(transaction_hash())

        expect_discovery(rollup_block_hash(batch, 20), confirmation_transaction_hash)

        assert :confirmation_missed == discover(json_rpc_named_arguments)

        assert Repo.get_by(LifecycleTransaction, hash: confirmation_transaction_hash) == nil

        assert unconfirmed_blocks() == Enum.to_list(11..20)

        seed_batch(@rollup_first_block, 10, @previous_commitment_l1_block)

        assert :ok == discover(json_rpc_named_arguments)

        confirmation = Repo.get_by!(LifecycleTransaction, hash: confirmation_transaction_hash)
        assert confirmed_blocks(confirmation) == Enum.to_list(@rollup_first_block..20)
        assert unconfirmed_blocks() == []
      end

      # The database has one batch of the blocks 11..20. No block of the batch is
      # confirmed. The rollup blocks 1..10 are also in the database, but no batch of
      # the database holds them. If the indexer did not handle the batch of those
      # blocks, the database has this state.
      #
      # The discovery range holds one event, and that event points to the rollup
      # block 20. The parent chain holds an earlier event in an older parent chain
      # block. That older block is outside the discovery range, and the earlier event
      # points to the rollup block 10.
      #
      # The lookup of the confirmation reads the parent chain from the commitment of
      # the batch to the block before the event. That range holds the log of the
      # earlier event. The discovery finds the number of a rollup block through the
      # batch of that block. The block 10 has no batch. Thus the lookup gives an
      # error.
      #
      # The discovery writes nothing after that error. The walk to the batch below
      # does not start. The return value is `:confirmation_missed`.
      #
      # Two other tests give the same result. The test "postpones both confirmations
      # when the batch of the lower confirmed block is missing" holds the same state
      # of the database. In that test the two events are in the discovery range. The
      # test "postpones the confirmation when the batch below the current one is
      # missing" holds no earlier event. In that test the rollup blocks 1..10 are not
      # in the database. Thus the position of the earlier event does not change the
      # result.
      #
      # The second part of the test makes the change of the indexer: the indexer
      # writes the batch of the blocks 1..10. Then the discovery examines the same
      # parent chain range again, and the confirmation covers the blocks 11..20. The
      # blocks 1..10 stay unconfirmed. Those blocks belong to the earlier
      # confirmation. A later run of the historical discovery reaches the earlier
      # event, and that run links those blocks to that event.
      test "postpones the confirmation when an out-of-range earlier event points to a block without a batch", %{
        json_rpc_named_arguments: json_rpc_named_arguments
      } do
        blocks_without_batch = seed_blocks_without_batch(@rollup_first_block, 10)
        batch = seed_batch(11, 20, @commitment_l1_block)

        earlier_confirmation_transaction_hash = to_string(transaction_hash())
        confirmation_transaction_hash = to_string(transaction_hash())

        expect_discovery_of([
          build_send_root_updated_log(
            rollup_block_hash(blocks_without_batch, 10),
            earlier_confirmation_transaction_hash,
            @earlier_confirmation_l1_block
          ),
          build_send_root_updated_log(
            rollup_block_hash(batch, 20),
            confirmation_transaction_hash,
            @confirmation_l1_block
          )
        ])

        assert :confirmation_missed == discover(json_rpc_named_arguments)

        assert Repo.get_by(LifecycleTransaction, hash: confirmation_transaction_hash) == nil
        assert Repo.get_by(LifecycleTransaction, hash: earlier_confirmation_transaction_hash) == nil

        assert unconfirmed_blocks() == Enum.to_list(11..20)

        seed_batch_of_blocks(blocks_without_batch, @previous_commitment_l1_block)

        assert :ok == discover(json_rpc_named_arguments)

        confirmation = Repo.get_by!(LifecycleTransaction, hash: confirmation_transaction_hash)
        assert confirmed_blocks(confirmation) == Enum.to_list(11..20)
        assert Repo.get_by(LifecycleTransaction, hash: earlier_confirmation_transaction_hash) == nil
        assert unconfirmed_blocks() == Enum.to_list(@rollup_first_block..10)
      end

      # The database has one batch of the blocks 1..10. No block of it is confirmed.
      # The block 3 is not linked to the batch, and the block 5 is linked to it. If the
      # indexer did not handle the whole batch, the database has this state.
      #
      # The parent chain holds two events. The earlier event points to the rollup
      # block 5, and it is outside the discovery range. The event under discovery
      # points to the rollup block 10.
      #
      # The lookup of the confirmation finds the log of the earlier event. That log
      # points to the block 5, which is in the middle of the batch. Thus the range of
      # the confirmation starts at the block 6. The selection of the blocks holds the
      # blocks 6..10, and the missing link of the block 3 is below that range.
      # Therefore the incomplete data does not take part in the checks of the
      # continuity and of the count.
      #
      # As a result, the confirmation covers the blocks 6..10, and the result is `:ok`.
      # The blocks below the block 6 belong to the earlier confirmation. A later run of
      # the historical discovery reaches the earlier event. That run needs the link of
      # the block 3, and the indexer writes it before that run.
      #
      # This test is the only one where the batch of the event is incomplete and the
      # discovery still writes the confirmation.
      test "confirms its range when the data below the earlier confirmation is incomplete", %{
        json_rpc_named_arguments: json_rpc_named_arguments
      } do
        batch = seed_batch(@rollup_first_block, 10, @commitment_l1_block, unlinked_blocks: [3])

        earlier_confirmation_transaction_hash = to_string(transaction_hash())
        confirmation_transaction_hash = to_string(transaction_hash())

        expect_discovery_of([
          build_send_root_updated_log(
            rollup_block_hash(batch, 5),
            earlier_confirmation_transaction_hash,
            @earlier_confirmation_l1_block
          ),
          build_send_root_updated_log(
            rollup_block_hash(batch, 10),
            confirmation_transaction_hash,
            @confirmation_l1_block
          )
        ])

        assert :ok == discover(json_rpc_named_arguments)

        confirmation = Repo.get_by!(LifecycleTransaction, hash: confirmation_transaction_hash)
        assert confirmed_blocks(confirmation) == Enum.to_list(6..10)

        # The discovery reads the log of the earlier event only to find the bottom of
        # the current confirmation. It does not import that transaction.
        refute Repo.get_by(LifecycleTransaction, hash: earlier_confirmation_transaction_hash)

        # The blocks below the block 6 stay for the earlier confirmation. The block 3
        # holds no link to the batch, thus it is not in this list.
        assert unconfirmed_blocks() == [@rollup_first_block, 2, 4, 5]
      end

      # The database has one batch of the blocks 1..10. No block of it is confirmed.
      # The block 9 is not linked to the batch. The blocks 1..7 and their links to the
      # batch are in the database. If the indexer did not handle the whole batch, the
      # database has this state.
      #
      # The event points to the rollup block 7, which is in the middle of the batch.
      #
      # The discovery selects the unconfirmed blocks of the batch up to the block 7.
      # Thus the missing link of the block 9 is above that selection, and it does not
      # take part in the checks of the continuity and of the count. The lookup finds no
      # earlier confirmation, and the batch starts at the lowest-indexed rollup block.
      #
      # As a result, the confirmation covers the blocks 1..7, and the result is `:ok`.
      # The blocks above the block 7 wait for the next confirmation, and the indexer
      # writes the link of the block 9 before the run of that confirmation.
      #
      # This test holds the counterpart of the test "confirms its range when the data
      # below the earlier confirmation is incomplete". There the incomplete data is
      # below the range of the confirmation, and here it is above the top block of the
      # event.
      test "confirms its range when the data above the confirmed block is incomplete", %{
        json_rpc_named_arguments: json_rpc_named_arguments
      } do
        batch = seed_batch(@rollup_first_block, 10, @commitment_l1_block, unlinked_blocks: [9])

        confirmation_transaction_hash = to_string(transaction_hash())

        expect_discovery(rollup_block_hash(batch, 7), confirmation_transaction_hash)

        assert :ok == discover(json_rpc_named_arguments)

        confirmation = Repo.get_by!(LifecycleTransaction, hash: confirmation_transaction_hash)
        assert confirmed_blocks(confirmation) == Enum.to_list(@rollup_first_block..7)

        # The block 9 holds no link to the batch, thus it is not in this list.
        assert unconfirmed_blocks() == [8, 10]
      end
    end
  end
end
