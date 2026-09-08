# SPDX-License-Identifier: LicenseRef-Blockscout
if Application.get_env(:explorer, :chain_type) == :arbitrum do
  defmodule Indexer.Fetcher.Arbitrum.Workers.Confirmations.Discovery.NewConfirmationTest do
    use Indexer.Fetcher.Arbitrum.Workers.Confirmations.Discovery.TestCase

    # See `Indexer.Fetcher.Arbitrum.Workers.Confirmations.Discovery.TestCase` for
    # the conventions this suite of files follows.

    # A `SendRootUpdated` event on the parent chain confirms one rollup block. The
    # event also confirms all rollup blocks below that block, down to the block of
    # the confirmation before it.
    #
    # Each test in this group gives the discovery one such event. The parent chain
    # transaction of the event is not in the database yet. Thus the discovery must
    # find all rollup blocks that belong to this confirmation.
    #
    # The discovery starts with the batch that contains the confirmed block. Then it
    # can continue to the previous batch. The walk stops on one of these conditions:
    #   - the discovery finds an earlier confirmation inside the batch
    #   - all blocks of the batch below are confirmed already
    #   - the batch starts at the lowest-indexed rollup block
    #
    # To find an earlier confirmation, the discovery reads the parent chain logs
    # between the commitment of the batch and the confirmation under discovery.
    describe "perform/5 with a new confirmation" do
      # The database has one batch with the rollup blocks 1..10. No block of it is
      # confirmed.
      #
      # The event points to the rollup block 10, which is the highest block of the
      # batch. No earlier confirmation exists on the parent chain. The batch starts
      # at the lowest-indexed rollup block. As a result, the confirmation covers the
      # full batch.
      #
      # The discovery also changes the status of the L2-to-L1 messages. A message
      # that was sent in the block 10 or below becomes `:confirmed`. A message from
      # a higher block keeps the status `:sent`.
      test "confirms every rollup block of the batch and the L2-to-L1 messages up to the confirmed block", %{
        json_rpc_named_arguments: json_rpc_named_arguments
      } do
        batch = seed_batch(@rollup_first_block, 10, @commitment_l1_block)

        confirmation_transaction_hash = to_string(transaction_hash())
        confirmed_message = insert_sent_message_from_l2(9)
        # The top confirmed block belongs to the confirmation as well, thus a
        # message sent in that very block must change its status too.
        boundary_message = insert_sent_message_from_l2(10)
        not_yet_confirmed_message = insert_sent_message_from_l2(11)

        expect_discovery(rollup_block_hash(batch, 10), confirmation_transaction_hash)

        assert :ok == discover(json_rpc_named_arguments)

        # The parent chain transaction of the event becomes a lifecycle transaction.
        confirmation = Repo.get_by!(LifecycleTransaction, hash: confirmation_transaction_hash)
        assert confirmation.block_number == @confirmation_l1_block
        assert DateTime.to_unix(confirmation.timestamp) == @confirmation_l1_timestamp
        assert confirmation.status == :unfinalized

        # The full batch is linked to that lifecycle transaction.
        assert confirmed_blocks(confirmation) == Enum.to_list(@rollup_first_block..10)
        assert message_status(confirmed_message) == :confirmed
        assert message_status(boundary_message) == :confirmed
        assert message_status(not_yet_confirmed_message) == :sent
      end

      # The database has one batch with the rollup blocks 1..10. No block of it is
      # confirmed.
      #
      # The event points to the rollup block 7, which is in the middle of the batch:
      # a confirmation is not always aligned with the boundary of a batch. As a
      # result, the confirmation covers the blocks 1..7 only, and the blocks 8..10
      # wait for the next confirmation.
      test "confirms the blocks up to the confirmed block when that block is in the middle of the batch", %{
        json_rpc_named_arguments: json_rpc_named_arguments
      } do
        batch = seed_batch(@rollup_first_block, 10, @commitment_l1_block)

        confirmation_transaction_hash = to_string(transaction_hash())

        expect_discovery(rollup_block_hash(batch, 7), confirmation_transaction_hash)

        assert :ok == discover(json_rpc_named_arguments)

        confirmation = Repo.get_by!(LifecycleTransaction, hash: confirmation_transaction_hash)
        assert confirmed_blocks(confirmation) == Enum.to_list(@rollup_first_block..7)
        assert unconfirmed_blocks() == Enum.to_list(8..10)
      end

      # The database has one batch with the rollup blocks 1..10. An earlier
      # confirmation is known already, and it covers the blocks 1..5.
      #
      # The event points to the rollup block 10. In the parent chain range of the
      # batch, the discovery finds the log of the earlier confirmation. That log
      # points to the rollup block 5, which is in the middle of the batch. Thus the
      # new confirmation covers the blocks 6..10, and the walk stops in this batch.
      test "links only the blocks above an earlier confirmation which happened in the middle of the same batch", %{
        json_rpc_named_arguments: json_rpc_named_arguments
      } do
        batch = seed_batch(@rollup_first_block, 10, @commitment_l1_block)

        earlier_confirmation = insert_confirmation(@earlier_confirmation_l1_block)
        mark_confirmed(@rollup_first_block..5, earlier_confirmation)

        confirmation_transaction_hash = to_string(transaction_hash())

        expect_discovery_of([
          build_send_root_updated_log(
            rollup_block_hash(batch, 5),
            to_string(earlier_confirmation.hash),
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
        assert confirmed_blocks(earlier_confirmation) == Enum.to_list(@rollup_first_block..5)
      end

      # The database has one batch with the rollup blocks 1..10. A known
      # confirmation covers the blocks 6..10. The blocks 1..5 are not confirmed.
      #
      # The historical discovery usually holds this state. That discovery moves
      # backward, and it handles the newer confirmation first. The run of the newer
      # confirmation found the log of the earlier confirmation. Thus that run left the
      # blocks 1..5 for the earlier confirmation. The known confirmation is in the
      # parent chain block 210, which is more than the end block of the discovery range.
      #
      # The event points to the rollup block 5. The lookup range of the event ends
      # before the known confirmation, thus the lookup finds no log. The batch starts
      # at the lowest-indexed rollup block. As a result, the new confirmation covers
      # the blocks 1..5, and the known confirmation keeps the blocks 6..10. Only this
      # test holds a batch with upper blocks that are linked to another confirmation
      # already. In this test the event points below those blocks.
      test "confirms the blocks below a later known confirmation of the same batch", %{
        json_rpc_named_arguments: json_rpc_named_arguments
      } do
        batch = seed_batch(@rollup_first_block, 10, @commitment_l1_block)

        later_confirmation = insert_confirmation(@later_confirmation_l1_block, @confirmation_l1_timestamp + 120)
        mark_confirmed(6..10, later_confirmation)

        confirmation_transaction_hash = to_string(transaction_hash())

        expect_discovery_of([
          build_send_root_updated_log(
            rollup_block_hash(batch, 5),
            confirmation_transaction_hash,
            @confirmation_l1_block
          ),
          build_send_root_updated_log(
            rollup_block_hash(batch, 10),
            to_string(later_confirmation.hash),
            @later_confirmation_l1_block
          )
        ])

        assert :ok == discover(json_rpc_named_arguments)

        confirmation = Repo.get_by!(LifecycleTransaction, hash: confirmation_transaction_hash)
        assert confirmed_blocks(confirmation) == Enum.to_list(@rollup_first_block..5)
        assert confirmed_blocks(later_confirmation) == Enum.to_list(6..10)
        assert unconfirmed_blocks() == []
      end

      # The database has two batches: the blocks 1..10 and the blocks 11..20. An
      # earlier confirmation covers the full first batch. The blocks 11..20 are not
      # confirmed.
      #
      # The event points to the rollup block 20. The discovery finds no earlier
      # confirmation in the parent chain range of the second batch. Thus it moves to
      # the first batch. The database shows that all blocks of that batch are
      # confirmed. As a result, the walk stops, and the discovery asks for no logs
      # for the first batch.
      test "stops at the previous batch when all of its blocks are already confirmed", %{
        json_rpc_named_arguments: json_rpc_named_arguments
      } do
        seed_batch(@rollup_first_block, 10, @previous_commitment_l1_block)
        batch = seed_batch(11, 20, @commitment_l1_block)

        earlier_confirmation = insert_confirmation(@earlier_confirmation_l1_block)
        mark_confirmed(@rollup_first_block..10, earlier_confirmation)

        confirmation_transaction_hash = to_string(transaction_hash())

        expect_discovery(rollup_block_hash(batch, 20), confirmation_transaction_hash)

        assert :ok == discover(json_rpc_named_arguments)

        confirmation = Repo.get_by!(LifecycleTransaction, hash: confirmation_transaction_hash)
        assert confirmed_blocks(confirmation) == Enum.to_list(11..20)
        assert confirmed_blocks(earlier_confirmation) == Enum.to_list(@rollup_first_block..10)
        assert unconfirmed_blocks() == []
      end

      # The database has two batches: the blocks 1..10 and the blocks 11..20. No
      # block is confirmed. This state is usual for the historical discovery,
      # because that discovery moves backward and processes the newer confirmations
      # first.
      #
      # The event points to the rollup block 20. An earlier confirmation exists on
      # the parent chain, but the database does not know it yet. That confirmation
      # points to the rollup block 10, which is the last block of the first batch.
      #
      # In the range of the second batch, the log of the earlier confirmation points
      # below the first block of that batch. Thus the discovery ignores it there and
      # moves one batch down. In the range of the first batch, the same log points
      # exactly to the last block. As a result, the full first batch belongs to the
      # earlier confirmation, and the new confirmation covers the blocks 11..20.
      test "stops at the previous batch when an earlier confirmation covers exactly its last block", %{
        json_rpc_named_arguments: json_rpc_named_arguments
      } do
        previous_batch = seed_batch(@rollup_first_block, 10, @previous_commitment_l1_block)
        batch = seed_batch(11, 20, @commitment_l1_block)

        earlier_confirmation_transaction_hash = to_string(transaction_hash())

        earlier_confirmation_log =
          build_send_root_updated_log(
            rollup_block_hash(previous_batch, 10),
            earlier_confirmation_transaction_hash,
            @earlier_confirmation_l1_block
          )

        confirmation_transaction_hash = to_string(transaction_hash())

        expect_discovery_of([
          earlier_confirmation_log,
          build_send_root_updated_log(
            rollup_block_hash(batch, 20),
            confirmation_transaction_hash,
            @confirmation_l1_block
          )
        ])

        assert :ok == discover(json_rpc_named_arguments)

        confirmation = Repo.get_by!(LifecycleTransaction, hash: confirmation_transaction_hash)
        assert confirmed_blocks(confirmation) == Enum.to_list(11..20)

        # The blocks of the first batch stay for the earlier confirmation. One of
        # the next iterations of the discovery finds that confirmation.
        assert unconfirmed_blocks() == Enum.to_list(@rollup_first_block..10)

        # The discovery reads the log of the earlier confirmation only to find the
        # bottom of the current one. It does not import that transaction.
        refute Repo.get_by(LifecycleTransaction, hash: earlier_confirmation_transaction_hash)
      end

      # The database has two batches: the blocks 1..10 and the blocks 11..20. An
      # earlier confirmation covers the blocks 1..5.
      #
      # The event points to the rollup block 20. In the range of the second batch,
      # the log of the earlier confirmation points to the rollup block 5. That block
      # is below the batch, thus the discovery moves one batch down. In the range of
      # the first batch, the same log points to the block 5, which is in the middle
      # of that batch. As a result, the new confirmation covers the blocks 6..20.
      test "spans two batches down to an earlier confirmation in the middle of the previous batch", %{
        json_rpc_named_arguments: json_rpc_named_arguments
      } do
        previous_batch = seed_batch(@rollup_first_block, 10, @previous_commitment_l1_block)
        batch = seed_batch(11, 20, @commitment_l1_block)

        earlier_confirmation = insert_confirmation(@earlier_confirmation_l1_block)
        mark_confirmed(@rollup_first_block..5, earlier_confirmation)

        earlier_confirmation_log =
          build_send_root_updated_log(
            rollup_block_hash(previous_batch, 5),
            to_string(earlier_confirmation.hash),
            @earlier_confirmation_l1_block
          )

        confirmation_transaction_hash = to_string(transaction_hash())

        expect_discovery_of([
          earlier_confirmation_log,
          build_send_root_updated_log(
            rollup_block_hash(batch, 20),
            confirmation_transaction_hash,
            @confirmation_l1_block
          )
        ])

        assert :ok == discover(json_rpc_named_arguments)

        # The confirmation covers the end of the first batch and the full second
        # batch.
        confirmation = Repo.get_by!(LifecycleTransaction, hash: confirmation_transaction_hash)
        assert confirmed_blocks(confirmation) == Enum.to_list(6..20)
        assert confirmed_blocks(earlier_confirmation) == Enum.to_list(@rollup_first_block..5)
      end

      # The database has three batches: the blocks 1..5, the blocks 6..10 and the
      # blocks 11..15. No block is confirmed, and no earlier confirmation exists on
      # the parent chain.
      #
      # The event points to the rollup block 15. The discovery finds no earlier
      # confirmation in the range of each batch. Thus it continues to each previous
      # batch. The first batch starts at the lowest-indexed rollup block. As a
      # result, the walk stops there, and the confirmation covers the blocks 1..15.
      test "walks back through several batches until the lowest-indexed rollup block", %{
        json_rpc_named_arguments: json_rpc_named_arguments
      } do
        seed_batch(@rollup_first_block, 5, @oldest_commitment_l1_block)
        seed_batch(6, 10, @previous_commitment_l1_block)
        batch = seed_batch(11, 15, @commitment_l1_block)

        confirmation_transaction_hash = to_string(transaction_hash())

        expect_discovery(rollup_block_hash(batch, 15), confirmation_transaction_hash)

        assert :ok == discover(json_rpc_named_arguments)

        confirmation = Repo.get_by!(LifecycleTransaction, hash: confirmation_transaction_hash)
        assert confirmed_blocks(confirmation) == Enum.to_list(@rollup_first_block..15)
      end

      # The database has two batches: the blocks 1..10 and the blocks 11..20. No
      # block is confirmed, and no earlier confirmation exists on the parent chain.
      #
      # The event points to the rollup block 20, which is the last block of the
      # second batch. The discovery finds no earlier confirmation in the range of
      # that batch. Thus it moves to the first batch. That batch starts at the
      # lowest-indexed rollup block. As a result, the confirmation covers the blocks
      # 1..20.
      #
      # This test is not redundant. The test "walks back through several batches
      # until the lowest-indexed rollup block" makes the same walk, but its event
      # points to a block in the middle of a batch. This test is the only one where
      # an event on the boundary of a batch starts a walk which reaches the start of
      # the chain.
      test "walks back to the lowest-indexed rollup block when the event is on a batch boundary", %{
        json_rpc_named_arguments: json_rpc_named_arguments
      } do
        seed_batch(@rollup_first_block, 10, @previous_commitment_l1_block)
        batch = seed_batch(11, 20, @commitment_l1_block)

        confirmation_transaction_hash = to_string(transaction_hash())

        expect_discovery(rollup_block_hash(batch, 20), confirmation_transaction_hash)

        assert :ok == discover(json_rpc_named_arguments)

        confirmation = Repo.get_by!(LifecycleTransaction, hash: confirmation_transaction_hash)
        assert confirmed_blocks(confirmation) == Enum.to_list(@rollup_first_block..20)
      end

      # The database has one batch with the rollup blocks 1..10. The blocks 9 and 10
      # are linked to a parent chain transaction which is not the confirmation of
      # this range. The blocks 1..8 are not confirmed.
      #
      # Such a state occurs after a re-org, or after a wrong link. The event points
      # to the rollup block 10. Thus the discovery takes the blocks 9 and 10 from
      # the other transaction, and links the full batch to the new confirmation.
      test "re-links the blocks on top of the batch which were confirmed by another transaction", %{
        json_rpc_named_arguments: json_rpc_named_arguments
      } do
        batch = seed_batch(@rollup_first_block, 10, @commitment_l1_block)

        wrong_confirmation = insert_confirmation(@earlier_confirmation_l1_block)
        mark_confirmed(9..10, wrong_confirmation)

        confirmation_transaction_hash = to_string(transaction_hash())

        expect_discovery(rollup_block_hash(batch, 10), confirmation_transaction_hash)

        assert :ok == discover(json_rpc_named_arguments)

        # The full batch is linked to the new confirmation. The other transaction
        # keeps no block.
        confirmation = Repo.get_by!(LifecycleTransaction, hash: confirmation_transaction_hash)
        assert confirmed_blocks(confirmation) == Enum.to_list(@rollup_first_block..10)
        assert confirmed_blocks(wrong_confirmation) == []
      end

      # The database has one batch with the rollup blocks 1..10. All blocks of it are
      # linked to a parent chain transaction which is not the confirmation of this
      # range.
      #
      # Such a state occurs after a re-org. The discovery imported the confirmation
      # before its parent chain block became safe, and the re-org replaced that
      # transaction. After the re-org the parent chain does not hold the log of the
      # replaced transaction.
      #
      # The event points to the rollup block 10. It confirms the same blocks as the
      # replaced transaction. Thus the discovery must take the blocks 1..10 from the
      # other transaction, and it must link the full batch to the new confirmation.
      # The test "re-links the blocks on top of the batch which were confirmed by
      # another transaction" holds the same re-link for a part of the batch.
      #
      # The batch holds no unconfirmed block, and the number of its confirmed blocks
      # is equal to the size of the batch. The discovery reads this state as a batch
      # which needs no work, and it gives no block to the confirmation. The re-link
      # of the blocks on top of a batch starts from the highest unconfirmed block of
      # the batch. In this state no block is unconfirmed, thus the re-link does not
      # start. The discovery writes nothing, and it returns `:confirmation_missed`.
      #
      # The first part of the test keeps `:confirmation_missed`, which is the current
      # result. The second part changes nothing in the database. The indexer has
      # nothing to add, because the batch is complete. Thus the repeated run of the
      # same parent chain range must give `:ok`. The discovery gives
      # `:confirmation_missed` again, and the test fails on that assertion.
      # Therefore the historical discovery reads this range again and again.
      @tag skip: "Defect: a batch confirmed in full by another transaction repeats the range"
      test "re-links the batch which another transaction confirmed in full", %{
        json_rpc_named_arguments: json_rpc_named_arguments
      } do
        batch = seed_batch(@rollup_first_block, 10, @commitment_l1_block)

        wrong_confirmation = insert_confirmation(@earlier_confirmation_l1_block)
        mark_confirmed(@rollup_first_block..10, wrong_confirmation)

        confirmation_transaction_hash = to_string(transaction_hash())

        expect_discovery(rollup_block_hash(batch, 10), confirmation_transaction_hash)

        assert :confirmation_missed == discover(json_rpc_named_arguments)

        assert Repo.get_by(LifecycleTransaction, hash: confirmation_transaction_hash) == nil
        assert confirmed_blocks(wrong_confirmation) == Enum.to_list(@rollup_first_block..10)

        assert :ok == discover(json_rpc_named_arguments)

        confirmation = Repo.get_by!(LifecycleTransaction, hash: confirmation_transaction_hash)
        assert confirmed_blocks(confirmation) == Enum.to_list(@rollup_first_block..10)
        assert confirmed_blocks(wrong_confirmation) == []
      end

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

      # The database has two batches: the blocks 1..10 and the blocks 11..20. No
      # block is confirmed.
      #
      # The parent chain holds two events. The earlier event points to the rollup
      # block 20, and it is outside the discovery range. The newer event points to
      # the rollup block 10, and it is in the discovery range. Thus the newer
      # transaction confirms the lower rollup blocks.
      #
      # The two blocks are in two different batches. The lookup of the newer
      # confirmation examines the batch of the block 10 only. The log of the earlier
      # event points to a block above that batch. Thus the lookup does not use that
      # log, and the newer confirmation covers the blocks 1..10.
      #
      # The blocks 11..20 stay unconfirmed. Those blocks belong to the earlier
      # confirmation. A later run of the historical discovery reaches the earlier
      # event, and that run links those blocks to that event.
      #
      # This test holds the same order of the two events as the test "confirms the
      # blocks below an earlier confirmation of the same batch". The difference is the
      # batch: here the two blocks are in two batches, and there they are in one
      # batch. One batch gives a defect, and two batches give the correct result.
      test "confirms the blocks below an earlier confirmation of another batch", %{
        json_rpc_named_arguments: json_rpc_named_arguments
      } do
        previous_batch = seed_batch(@rollup_first_block, 10, @previous_commitment_l1_block)
        batch = seed_batch(11, 20, @commitment_l1_block)

        earlier_confirmation_log =
          build_send_root_updated_log(
            rollup_block_hash(batch, 20),
            to_string(transaction_hash()),
            @earlier_confirmation_l1_block
          )

        confirmation_transaction_hash = to_string(transaction_hash())

        expect_discovery_of([
          earlier_confirmation_log,
          build_send_root_updated_log(
            rollup_block_hash(previous_batch, 10),
            confirmation_transaction_hash,
            @confirmation_l1_block
          )
        ])

        assert :ok == discover(json_rpc_named_arguments)

        confirmation = Repo.get_by!(LifecycleTransaction, hash: confirmation_transaction_hash)
        assert confirmation.block_number == @confirmation_l1_block
        assert DateTime.to_unix(confirmation.timestamp) == @confirmation_l1_timestamp

        assert confirmed_blocks(confirmation) == Enum.to_list(@rollup_first_block..10)
        assert unconfirmed_blocks() == Enum.to_list(11..20)
      end

      # The database has one batch of the blocks 1..10. No block of it is confirmed.
      #
      # The parent chain holds two events. The earlier event points to the rollup
      # block 10, and it is outside the discovery range. The newer event points to
      # the rollup block 5, and it is in the discovery range. Thus the newer
      # transaction confirms the lower rollup blocks. The HPP mainnet, which is an
      # Arbitrum AnyTrust chain, holds such a pair of confirmations.
      #
      # The newer event confirms the blocks 1..5. Thus the discovery must write that
      # confirmation with the blocks 1..5. The blocks 6..10 belong to the earlier
      # confirmation. A later run of the historical discovery reaches the earlier
      # event, and that run links those blocks to that event.
      #
      # The discovery finds the log of the earlier event in the lookup range of the
      # newer event. That log points to the block 10. Thus the discovery takes the
      # block 11 as the first unconfirmed block of the batch. The block 11 is above
      # the block 5. Therefore the discovery finds no block for the confirmation, and
      # it writes nothing. The return value is `:confirmation_missed`.
      #
      # The first part of the test keeps `:confirmation_missed`, which is the current
      # result. The second part changes nothing in the database. The database holds
      # the whole batch already, and the indexer has nothing to add. Thus the repeated
      # run of the same parent chain range must give `:ok`. The discovery
      # gives `:confirmation_missed` again, and the test fails on that assertion.
      # Therefore the historical discovery reads this range again and again.
      #
      # The correction of the defect gives `:ok` and the blocks 1..5 in the first run.
      # No other form is possible here. The database holds the whole batch already,
      # thus no change of the database can end the postponement.
      @tag skip: "Defect: a confirmation below an earlier confirmation of the same batch repeats the range"
      test "confirms the blocks below an earlier confirmation of the same batch", %{
        json_rpc_named_arguments: json_rpc_named_arguments
      } do
        batch = seed_batch(@rollup_first_block, 10, @commitment_l1_block)

        earlier_confirmation_log =
          build_send_root_updated_log(
            rollup_block_hash(batch, 10),
            to_string(transaction_hash()),
            @earlier_confirmation_l1_block
          )

        confirmation_transaction_hash = to_string(transaction_hash())

        expect_discovery_of([
          earlier_confirmation_log,
          build_send_root_updated_log(
            rollup_block_hash(batch, 5),
            confirmation_transaction_hash,
            @confirmation_l1_block
          )
        ])

        assert :confirmation_missed == discover(json_rpc_named_arguments)

        assert Repo.get_by(LifecycleTransaction, hash: confirmation_transaction_hash) == nil
        assert unconfirmed_blocks() == Enum.to_list(@rollup_first_block..10)

        assert :ok == discover(json_rpc_named_arguments)

        confirmation = Repo.get_by!(LifecycleTransaction, hash: confirmation_transaction_hash)
        assert confirmation.block_number == @confirmation_l1_block
        assert DateTime.to_unix(confirmation.timestamp) == @confirmation_l1_timestamp

        assert confirmed_blocks(confirmation) == Enum.to_list(@rollup_first_block..5)
        assert unconfirmed_blocks() == Enum.to_list(6..10)
      end

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
      # With the value 1 the discovery stops at the block 1 for two reasons: the block
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
      # This test holds the second reason of the stop at the block 1 only. The test
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
