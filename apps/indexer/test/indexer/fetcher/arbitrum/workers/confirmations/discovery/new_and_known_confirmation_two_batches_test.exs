# SPDX-License-Identifier: LicenseRef-Blockscout
if Application.get_env(:explorer, :chain_type) == :arbitrum do
  defmodule Indexer.Fetcher.Arbitrum.Workers.Confirmations.Discovery.NewAndKnownConfirmationTwoBatchesTest do
    use Indexer.Fetcher.Arbitrum.Workers.Confirmations.Discovery.TestCase

    # See `Indexer.Fetcher.Arbitrum.Workers.Confirmations.Discovery.TestCase` for
    # the conventions this suite of files follows.

    # A parent chain range can hold one new confirmation together with a confirmation
    # that the database knows already. The discovery examines the rollup blocks of
    # the new confirmation only. For the known confirmation it compares the block
    # number and the timestamp with the values of the event. If the values are
    # different, the discovery writes the known transaction again.
    #
    # Both results go into the database in the same operation.
    #
    # In this group the two confirmations sit in two different batches. The walk of
    # the new confirmation stops at one of two points. It stops at the log of the
    # known confirmation, or at the database state that shows the batch below as
    # fully confirmed. Thus the four positions of the two events on the parent chain
    # give the same result. The known confirmation can be older, newer, or in the
    # same parent chain block as the new one.
    #
    # A known confirmation can hold a part of the batch below. When its event is in
    # the parent chain block of the new confirmation, it gives neither of the two
    # boundaries. The last scenario of this group holds that state. It is the only
    # scenario in this group that gives a defect.
    #
    # The group "perform/5 with a new confirmation and a known one in one batch"
    # holds the same four positions within one batch. Three of them give a defect.
    # The group "perform/5 with a new confirmation and a known one over an
    # incomplete database" holds different scenarios. In each one, a batch is
    # missing part of its data.
    describe "perform/5 with a new confirmation and a known one in two batches" do
      # The database has two batches: the blocks 1..10 and the blocks 11..20. The
      # known confirmation holds the blocks 1..10 already. The block number and the
      # timestamp of that confirmation are equal to the values in its event.
      #
      # The new event points to the rollup block 20. The discovery finds no
      # confirmation within the blocks of the second batch. Thus it moves one batch
      # down. In the first batch the database shows that all blocks are confirmed
      # already. Thus the walk stops, and the discovery requests no logs for the
      # range of that batch.
      #
      # The known confirmation shows no difference. Thus the discovery keeps it as
      # it is. The result is `:ok`, because the discovery handles both events.
      test "confirms the new blocks and keeps the known confirmation which did not move", %{
        json_rpc_named_arguments: json_rpc_named_arguments
      } do
        previous_batch = seed_batch(@rollup_first_block, 10, @previous_commitment_l1_block)
        batch = seed_batch(11, 20, @commitment_l1_block)

        known_confirmation = insert_confirmation(@lower_confirmation_l1_block, @lower_confirmation_l1_timestamp)
        mark_confirmed(@rollup_first_block..10, known_confirmation)

        known_confirmation_transaction_hash = to_string(known_confirmation.hash)
        new_confirmation_transaction_hash = to_string(transaction_hash())

        known_confirmation_log =
          build_send_root_updated_log(
            rollup_block_hash(previous_batch, 10),
            known_confirmation_transaction_hash,
            @lower_confirmation_l1_block
          )

        new_confirmation_log =
          build_send_root_updated_log(
            rollup_block_hash(batch, 20),
            new_confirmation_transaction_hash,
            @confirmation_l1_block
          )

        expect_discovery_of([known_confirmation_log, new_confirmation_log])

        assert :ok == discover(json_rpc_named_arguments)

        new_confirmation = Repo.get_by!(LifecycleTransaction, hash: new_confirmation_transaction_hash)
        assert confirmed_blocks(new_confirmation) == Enum.to_list(11..20)

        kept_confirmation = Repo.get_by!(LifecycleTransaction, hash: known_confirmation.hash)
        assert kept_confirmation.id == known_confirmation.id
        assert kept_confirmation.block_number == @lower_confirmation_l1_block
        assert DateTime.compare(kept_confirmation.timestamp, known_confirmation.timestamp) == :eq
        assert confirmed_blocks(kept_confirmation) == Enum.to_list(@rollup_first_block..10)

        assert unconfirmed_blocks() == []
      end

      # The database has two batches: the blocks 1..10 and the blocks 11..20. The
      # known confirmation holds the blocks 1..5 only. Thus it covers a part of the
      # first batch. The number of its parent chain block and its timestamp are equal
      # to the values in its event.
      #
      # The new event points to the rollup block 20. The discovery finds no
      # confirmation within the blocks of the second batch. Thus it continues with
      # the previous batch. This time, the blocks 6..10 of the first batch are
      # unconfirmed, so the database does not stop the walk. Thus the discovery reads
      # the range of that batch and finds the log of the known confirmation there.
      # That log points to the block 5, which is in the middle of the batch.
      #
      # As a result, the blocks 6..10 go to the new confirmation. They do not go to
      # the known one. The discovery never extends a confirmation that it knows
      # already.
      #
      # This test is not redundant. It uses the walk of the single-event
      # test "spans two batches down to an earlier confirmation in the middle of the
      # previous batch". In this test the log of the known confirmation does two jobs
      # in one run. The log is the lifecycle transaction that the discovery compares
      # with its event. The log is also the boundary that ends the walk of the new
      # confirmation. This test is the only scenario where one log of the range does
      # both jobs.
      test "walks into the batch of the known confirmation when that confirmation covers a part of it", %{
        json_rpc_named_arguments: json_rpc_named_arguments
      } do
        previous_batch = seed_batch(@rollup_first_block, 10, @previous_commitment_l1_block)
        batch = seed_batch(11, 20, @commitment_l1_block)

        known_confirmation = insert_confirmation(@lower_confirmation_l1_block, @lower_confirmation_l1_timestamp)
        mark_confirmed(@rollup_first_block..5, known_confirmation)

        new_confirmation_transaction_hash = to_string(transaction_hash())

        known_confirmation_log =
          build_send_root_updated_log(
            rollup_block_hash(previous_batch, 5),
            to_string(known_confirmation.hash),
            @lower_confirmation_l1_block
          )

        new_confirmation_log =
          build_send_root_updated_log(
            rollup_block_hash(batch, 20),
            new_confirmation_transaction_hash,
            @confirmation_l1_block
          )

        expect_discovery_of([known_confirmation_log, new_confirmation_log])

        assert :ok == discover(json_rpc_named_arguments)

        new_confirmation = Repo.get_by!(LifecycleTransaction, hash: new_confirmation_transaction_hash)
        assert confirmed_blocks(new_confirmation) == Enum.to_list(6..20)

        kept_confirmation = Repo.get_by!(LifecycleTransaction, hash: known_confirmation.hash)
        assert kept_confirmation.id == known_confirmation.id
        assert kept_confirmation.block_number == @lower_confirmation_l1_block
        assert DateTime.compare(kept_confirmation.timestamp, known_confirmation.timestamp) == :eq
        assert confirmed_blocks(kept_confirmation) == Enum.to_list(@rollup_first_block..5)

        assert unconfirmed_blocks() == []
      end

      # The database has the same two batches, and the known confirmation holds the
      # blocks 1..10 already. A re-org moved that confirmation. The database holds
      # the parent chain block 190, but the event of the confirmation is in the
      # block 198.
      #
      # Thus the discovery writes two changes in one operation. It puts the new
      # parent chain block and the new timestamp into the known transaction. It
      # also links the blocks 11..20 to the new confirmation. The known transaction
      # keeps its identifier and its rollup blocks.
      test "confirms the new blocks and moves the known confirmation to its new parent chain block", %{
        json_rpc_named_arguments: json_rpc_named_arguments
      } do
        previous_batch = seed_batch(@rollup_first_block, 10, @previous_commitment_l1_block)
        batch = seed_batch(11, 20, @commitment_l1_block)

        known_confirmation = insert_confirmation(@stale_confirmation_l1_block)
        mark_confirmed(@rollup_first_block..10, known_confirmation)

        known_confirmation_transaction_hash = to_string(known_confirmation.hash)
        new_confirmation_transaction_hash = to_string(transaction_hash())

        known_confirmation_log =
          build_send_root_updated_log(
            rollup_block_hash(previous_batch, 10),
            known_confirmation_transaction_hash,
            @lower_confirmation_l1_block
          )

        new_confirmation_log =
          build_send_root_updated_log(
            rollup_block_hash(batch, 20),
            new_confirmation_transaction_hash,
            @confirmation_l1_block
          )

        expect_discovery_of([known_confirmation_log, new_confirmation_log])

        assert :ok == discover(json_rpc_named_arguments)

        new_confirmation = Repo.get_by!(LifecycleTransaction, hash: new_confirmation_transaction_hash)
        assert new_confirmation.block_number == @confirmation_l1_block
        assert confirmed_blocks(new_confirmation) == Enum.to_list(11..20)

        updated_confirmation = Repo.get_by!(LifecycleTransaction, hash: known_confirmation.hash)
        assert updated_confirmation.id == known_confirmation.id
        assert updated_confirmation.block_number == @lower_confirmation_l1_block
        assert DateTime.to_unix(updated_confirmation.timestamp) == @lower_confirmation_l1_timestamp
        assert updated_confirmation.status == known_confirmation.status
        assert confirmed_blocks(updated_confirmation) == Enum.to_list(@rollup_first_block..10)
      end

      # The database has two batches: the blocks 1..10 and the blocks 11..20. The
      # known confirmation holds the blocks 11..20 already. Its parent chain block
      # and its timestamp are equal to the values in its event, which is in the block
      # 200. The new event is in the block 198, and it points to the rollup block 10.
      #
      # The historical discovery usually holds this state. That discovery moves
      # backward. Thus an earlier run handles the newer confirmation. In this run the
      # range holds the two events, and the new event is the older one.
      #
      # The discovery examines the first batch only. The lookup range of the new
      # confirmation ends before the block 198, and it holds no log. Thus the new
      # confirmation covers the blocks 1..10. The known confirmation shows no
      # difference, and the discovery keeps it as it is. The result is `:ok`.
      test "confirms the blocks below the known confirmation when the new event is the older one", %{
        json_rpc_named_arguments: json_rpc_named_arguments
      } do
        previous_batch = seed_batch(@rollup_first_block, 10, @previous_commitment_l1_block)
        batch = seed_batch(11, 20, @commitment_l1_block)

        known_confirmation = insert_confirmation(@confirmation_l1_block, @confirmation_l1_timestamp)
        mark_confirmed(11..20, known_confirmation)

        new_confirmation_transaction_hash = to_string(transaction_hash())

        new_confirmation_log =
          build_send_root_updated_log(
            rollup_block_hash(previous_batch, 10),
            new_confirmation_transaction_hash,
            @lower_confirmation_l1_block
          )

        known_confirmation_log =
          build_send_root_updated_log(
            rollup_block_hash(batch, 20),
            to_string(known_confirmation.hash),
            @confirmation_l1_block
          )

        expect_discovery_of([new_confirmation_log, known_confirmation_log])

        assert :ok == discover(json_rpc_named_arguments)

        new_confirmation = Repo.get_by!(LifecycleTransaction, hash: new_confirmation_transaction_hash)
        assert new_confirmation.block_number == @lower_confirmation_l1_block
        assert confirmed_blocks(new_confirmation) == Enum.to_list(@rollup_first_block..10)

        kept_confirmation = Repo.get_by!(LifecycleTransaction, hash: known_confirmation.hash)
        assert kept_confirmation.id == known_confirmation.id
        assert kept_confirmation.block_number == @confirmation_l1_block
        assert DateTime.compare(kept_confirmation.timestamp, known_confirmation.timestamp) == :eq
        assert confirmed_blocks(kept_confirmation) == Enum.to_list(11..20)

        assert unconfirmed_blocks() == []
      end

      # The database has two batches: the blocks 1..10 and the blocks 11..20. The known
      # confirmation holds the full first batch, and its parent chain block and its
      # timestamp are equal to the values in its event. Both events are in the parent
      # chain block 200.
      #
      # The new event points to the rollup block 20. The discovery finds no
      # confirmation within the blocks of the second batch. Thus it moves one batch
      # down. The database shows that all blocks of the first batch are confirmed. Thus
      # the walk stops there, and the new confirmation covers the blocks 11..20.
      #
      # The test "confirms the new blocks and keeps the known confirmation which did
      # not move" holds the same database state. There, the known event is in an older
      # parent chain block. This test is the only one where the two batches split
      # between a known confirmation and a new one of the same parent chain block. The
      # state of the database, and not the parent chain, ends the walk here. Thus the
      # position of the known event does not change the result. The test "postpones the
      # new confirmation when the known one is in the middle of the batch below" holds
      # the same pair of events. There, the known confirmation is inside the first
      # batch. There the database ends no walk, and the result is a defect.
      test "splits two batches between the known lower confirmation and the new upper one of the same parent chain block",
           %{json_rpc_named_arguments: json_rpc_named_arguments} do
        previous_batch = seed_batch(@rollup_first_block, 10, @previous_commitment_l1_block)
        batch = seed_batch(11, 20, @commitment_l1_block)

        known_confirmation = insert_confirmation(@confirmation_l1_block, @confirmation_l1_timestamp)
        mark_confirmed(@rollup_first_block..10, known_confirmation)

        new_confirmation_transaction_hash = to_string(transaction_hash())

        expect_discovery_of([
          build_send_root_updated_log(
            rollup_block_hash(previous_batch, 10),
            to_string(known_confirmation.hash),
            @confirmation_l1_block
          ),
          build_send_root_updated_log(
            rollup_block_hash(batch, 20),
            new_confirmation_transaction_hash,
            @confirmation_l1_block,
            log_index: 1,
            transaction_index: 1
          )
        ])

        assert :ok == discover(json_rpc_named_arguments)

        new_confirmation = Repo.get_by!(LifecycleTransaction, hash: new_confirmation_transaction_hash)
        assert confirmed_blocks(new_confirmation) == Enum.to_list(11..20)

        kept_confirmation = Repo.get_by!(LifecycleTransaction, hash: known_confirmation.hash)
        assert kept_confirmation.id == known_confirmation.id
        assert kept_confirmation.block_number == @confirmation_l1_block
        assert DateTime.compare(kept_confirmation.timestamp, known_confirmation.timestamp) == :eq
        assert confirmed_blocks(kept_confirmation) == Enum.to_list(@rollup_first_block..10)

        assert unconfirmed_blocks() == []
      end

      # The database has two batches: the blocks 1..10 and the blocks 11..20. The known
      # confirmation holds the blocks 1..5, which is a part of the first batch. Its
      # values are equal to the values in its event. Both events are in the parent
      # chain block 200.
      #
      # The new event points to the rollup block 20. Thus the new confirmation must
      # cover the blocks 6..20, and the known confirmation must keep the blocks 1..5.
      #
      # The lookup range of the new confirmation ends one block before the parent chain
      # block of that confirmation. Thus no range of the walk holds the log of the known
      # confirmation. The first batch is not confirmed in full, so the walk collects
      # the blocks 11..20 and moves one batch down. There the discovery takes the block
      # 1 as the start of the range of the new confirmation. But the database gives
      # only the unconfirmed blocks 6..10. The discovery reads this difference as an
      # incomplete batch, and it drops the whole result of the new confirmation, the
      # blocks 11..20 included. It writes nothing, and it returns `:confirmation_missed`.
      #
      # The test "walks into the batch of the known confirmation when that confirmation
      # covers a part of it" holds the same database state. There, the known event is
      # in an older parent chain block. There the lookup range holds that log. The log
      # ends the walk, and the new confirmation covers the blocks 6..20. This test is
      # the only one with this pattern. The known confirmation sits in the same parent
      # chain block as the new one. It also covers part of the batch below the new
      # confirmation. Thus these two tests show that the position of the known event on
      # the parent chain changes the result for this database state.
      #
      # The test "splits two batches between the known lower confirmation and the new
      # upper one of the same parent chain block" holds the same positions. There, the
      # known confirmation is on the boundary of the first batch. There the state of
      # the database ends the walk. Thus the unseen log has no effect on the result.
      #
      # The second part of the test changes nothing in the database. The database holds
      # both batches already. Thus the indexer has nothing to add. Therefore the
      # repeated run of the same parent chain range must give `:ok` and the correct pair
      # of confirmations. The discovery gives `:confirmation_missed` again, and the
      # blocks 6..20 stay unconfirmed. Thus the historical discovery reads this range
      # again and again.
      #
      # The correction of the defect gives `:ok` and the blocks 6..20 in the first run.
      # Thus the person who removes the tag also removes the assertions of the first
      # part.
      @tag skip: "Defect: a new confirmation above a known one in the middle of a batch below repeats the range"
      test "postpones the new confirmation when the known one is in the middle of the batch below", %{
        json_rpc_named_arguments: json_rpc_named_arguments
      } do
        previous_batch = seed_batch(@rollup_first_block, 10, @previous_commitment_l1_block)
        batch = seed_batch(11, 20, @commitment_l1_block)

        known_confirmation = insert_confirmation(@confirmation_l1_block, @confirmation_l1_timestamp)
        mark_confirmed(@rollup_first_block..5, known_confirmation)

        new_confirmation_transaction_hash = to_string(transaction_hash())

        expect_discovery_of([
          build_send_root_updated_log(
            rollup_block_hash(previous_batch, 5),
            to_string(known_confirmation.hash),
            @confirmation_l1_block
          ),
          build_send_root_updated_log(
            rollup_block_hash(batch, 20),
            new_confirmation_transaction_hash,
            @confirmation_l1_block,
            log_index: 1,
            transaction_index: 1
          )
        ])

        assert :confirmation_missed == discover(json_rpc_named_arguments)

        assert Repo.get_by(LifecycleTransaction, hash: new_confirmation_transaction_hash) == nil
        assert confirmed_blocks(known_confirmation) == Enum.to_list(@rollup_first_block..5)
        assert unconfirmed_blocks() == Enum.to_list(6..20)

        assert :ok == discover(json_rpc_named_arguments)

        new_confirmation = Repo.get_by!(LifecycleTransaction, hash: new_confirmation_transaction_hash)
        assert new_confirmation.block_number == @confirmation_l1_block
        assert confirmed_blocks(new_confirmation) == Enum.to_list(6..20)

        kept_confirmation = Repo.get_by!(LifecycleTransaction, hash: known_confirmation.hash)
        assert kept_confirmation.id == known_confirmation.id
        assert DateTime.compare(kept_confirmation.timestamp, known_confirmation.timestamp) == :eq
        assert confirmed_blocks(kept_confirmation) == Enum.to_list(@rollup_first_block..5)

        assert unconfirmed_blocks() == []
      end

      # The database has two batches: the blocks 1..10 and the blocks 11..20. The known
      # confirmation holds the full second batch, and its values are equal to the
      # values in its event. Both events are in the parent chain block 200.
      #
      # The new event points to the rollup block 10. Thus the discovery examines the
      # first batch only. The lookup range of the new confirmation holds no log, and the
      # batch starts at the lowest-indexed rollup block. Thus the new confirmation
      # covers the full first batch.
      #
      # The test "confirms the blocks below the known confirmation when the new event is
      # the older one" holds the same database state. There, the new event is in an
      # older parent chain block. This test is the only one with this pattern. The new
      # confirmation of the lower batch and the known confirmation of the upper batch
      # are in one parent chain block.
      test "splits two batches between the new lower confirmation and the known upper one of the same parent chain block",
           %{json_rpc_named_arguments: json_rpc_named_arguments} do
        previous_batch = seed_batch(@rollup_first_block, 10, @previous_commitment_l1_block)
        batch = seed_batch(11, 20, @commitment_l1_block)

        known_confirmation = insert_confirmation(@confirmation_l1_block, @confirmation_l1_timestamp)
        mark_confirmed(11..20, known_confirmation)

        new_confirmation_transaction_hash = to_string(transaction_hash())

        expect_discovery_of([
          build_send_root_updated_log(
            rollup_block_hash(previous_batch, 10),
            new_confirmation_transaction_hash,
            @confirmation_l1_block
          ),
          build_send_root_updated_log(
            rollup_block_hash(batch, 20),
            to_string(known_confirmation.hash),
            @confirmation_l1_block,
            log_index: 1,
            transaction_index: 1
          )
        ])

        assert :ok == discover(json_rpc_named_arguments)

        new_confirmation = Repo.get_by!(LifecycleTransaction, hash: new_confirmation_transaction_hash)
        assert confirmed_blocks(new_confirmation) == Enum.to_list(@rollup_first_block..10)

        kept_confirmation = Repo.get_by!(LifecycleTransaction, hash: known_confirmation.hash)
        assert kept_confirmation.id == known_confirmation.id
        assert confirmed_blocks(kept_confirmation) == Enum.to_list(11..20)

        assert unconfirmed_blocks() == []
      end

      # The database has two batches: the blocks 1..10 and the blocks 11..20. The known
      # confirmation holds the full first batch, and its event is in the parent chain
      # block 200. The new event is in the parent chain block 198, and it points to the
      # rollup block 20. Thus the known confirmation of the lower blocks is the newer
      # one on the parent chain.
      #
      # The lookup range of the new confirmation ends before the parent chain block of
      # the known confirmation. Thus the lookup finds no log of it. But the database
      # shows that all blocks of the first batch are confirmed. Thus the walk stops at
      # that batch, and the new confirmation covers the blocks 11..20.
      #
      # The test "splits one batch when the known lower confirmation is newer on the
      # parent chain" holds the same pair of events within one batch. There the
      # discovery has no boundary and postpones the new confirmation. This test shows
      # that the state of the database gives the boundary when the two confirmations are
      # in two batches.
      test "splits two batches when the known lower confirmation is newer on the parent chain", %{
        json_rpc_named_arguments: json_rpc_named_arguments
      } do
        previous_batch = seed_batch(@rollup_first_block, 10, @previous_commitment_l1_block)
        batch = seed_batch(11, 20, @commitment_l1_block)

        known_confirmation = insert_confirmation(@confirmation_l1_block, @confirmation_l1_timestamp)
        mark_confirmed(@rollup_first_block..10, known_confirmation)

        new_confirmation_transaction_hash = to_string(transaction_hash())

        expect_discovery_of([
          build_send_root_updated_log(
            rollup_block_hash(batch, 20),
            new_confirmation_transaction_hash,
            @lower_confirmation_l1_block
          ),
          build_send_root_updated_log(
            rollup_block_hash(previous_batch, 10),
            to_string(known_confirmation.hash),
            @confirmation_l1_block
          )
        ])

        assert :ok == discover(json_rpc_named_arguments)

        new_confirmation = Repo.get_by!(LifecycleTransaction, hash: new_confirmation_transaction_hash)
        assert new_confirmation.block_number == @lower_confirmation_l1_block
        assert confirmed_blocks(new_confirmation) == Enum.to_list(11..20)

        kept_confirmation = Repo.get_by!(LifecycleTransaction, hash: known_confirmation.hash)
        assert kept_confirmation.id == known_confirmation.id
        assert confirmed_blocks(kept_confirmation) == Enum.to_list(@rollup_first_block..10)

        assert unconfirmed_blocks() == []
      end

      # The database has two batches: the blocks 1..10 and the blocks 11..20. The known
      # confirmation holds the full second batch, and its event is in the parent chain
      # block 198. The new event is in the parent chain block 200, and it points to the
      # rollup block 10. Thus the known confirmation of the upper blocks is the older
      # one on the parent chain.
      #
      # The lookup range of the new confirmation holds the log of the known
      # confirmation. That log points to the block 20, which is above the batch of the
      # new confirmation. Thus the discovery does not use that log, and the new
      # confirmation covers the full first batch.
      #
      # The test "splits one batch when the known upper confirmation is older on the
      # parent chain" holds the same pair of events within one batch. There the log of
      # the known confirmation points to a block of the same batch, and the discovery
      # postpones the new confirmation. Thus these two tests give the two results for
      # one pair of events. Two batches give the correct result, and one batch gives a
      # defect.
      test "splits two batches when the known upper confirmation is older on the parent chain", %{
        json_rpc_named_arguments: json_rpc_named_arguments
      } do
        previous_batch = seed_batch(@rollup_first_block, 10, @previous_commitment_l1_block)
        batch = seed_batch(11, 20, @commitment_l1_block)

        known_confirmation = insert_confirmation(@lower_confirmation_l1_block, @lower_confirmation_l1_timestamp)
        mark_confirmed(11..20, known_confirmation)

        new_confirmation_transaction_hash = to_string(transaction_hash())

        expect_discovery_of([
          build_send_root_updated_log(
            rollup_block_hash(batch, 20),
            to_string(known_confirmation.hash),
            @lower_confirmation_l1_block
          ),
          build_send_root_updated_log(
            rollup_block_hash(previous_batch, 10),
            new_confirmation_transaction_hash,
            @confirmation_l1_block
          )
        ])

        assert :ok == discover(json_rpc_named_arguments)

        new_confirmation = Repo.get_by!(LifecycleTransaction, hash: new_confirmation_transaction_hash)
        assert new_confirmation.block_number == @confirmation_l1_block
        assert confirmed_blocks(new_confirmation) == Enum.to_list(@rollup_first_block..10)

        kept_confirmation = Repo.get_by!(LifecycleTransaction, hash: known_confirmation.hash)
        assert kept_confirmation.id == known_confirmation.id
        assert kept_confirmation.block_number == @lower_confirmation_l1_block
        assert DateTime.compare(kept_confirmation.timestamp, known_confirmation.timestamp) == :eq
        assert confirmed_blocks(kept_confirmation) == Enum.to_list(11..20)

        assert unconfirmed_blocks() == []
      end
    end
  end
end
