# SPDX-License-Identifier: LicenseRef-Blockscout
if Application.get_env(:explorer, :chain_type) == :arbitrum do
  defmodule Indexer.Fetcher.Arbitrum.Workers.Confirmations.Discovery.NewAndKnownConfirmationTest do
    use Indexer.Fetcher.Arbitrum.Workers.Confirmations.Discovery.TestCase

    # See `Indexer.Fetcher.Arbitrum.Workers.Confirmations.Discovery.TestCase` for
    # the conventions this suite of files follows.

    # A parent chain range can hold one new confirmation together with a
    # confirmation which the database knows already. The discovery examines the
    # rollup blocks of the new confirmation only. For the known confirmation it
    # compares the block number and the timestamp with the values of the event. If the values are different, the discovery writes the known
    # transaction again.
    #
    # Both results go into the database in the same operation.
    describe "perform/5 with a new confirmation and an already known one" do
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
      # the previous batch. This time the database does not stop the walk, because
      # the blocks 6..10 of the first batch are unconfirmed. Thus the discovery reads
      # the range of that batch and finds the log of the known confirmation there.
      # That log points to the block 5, which is in the middle of the batch.
      #
      # As a result, the blocks 6..10 go to the new confirmation. They do not go to
      # the known one. The discovery never extends a confirmation which it knows
      # already.
      #
      # This test is not redundant. The walk itself is the walk of the single-event
      # test "spans two batches down to an earlier confirmation in the middle of the
      # previous batch". In this test the log of the known confirmation does two jobs
      # in one run. The log is the lifecycle transaction which the discovery compares
      # with its event. The log is also the boundary which ends the walk of the new
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

      # The database has one batch with the blocks 11..20, and the known confirmation
      # holds those blocks already. A re-org moved that confirmation. The database
      # holds the parent chain block 190, but the event of the confirmation is in the
      # block 200. The rollup blocks 1..10 are also in the database, but no batch of
      # the database holds them.
      #
      # The new event is in the block 198, and it points to the rollup block 10. The
      # discovery finds the number of a rollup block through the batch of that block.
      # Thus it cannot find the number of the block 10, and it drops the new event.
      # The known confirmation still shows a difference. Thus the discovery writes
      # the new parent chain block and the new timestamp into the known transaction,
      # and it returns `:confirmation_missed` in the same run.
      #
      # The second part of the test makes the change of the indexer: the indexer
      # writes the batch of the blocks 1..10. Then the discovery examines the same
      # parent chain range again. The new confirmation covers the blocks 1..10. The
      # known confirmation shows no difference. The result is `:ok`.
      test "postpones the new confirmation and moves the known one to its new parent chain block", %{
        json_rpc_named_arguments: json_rpc_named_arguments
      } do
        blocks_without_batch = seed_blocks_without_batch(@rollup_first_block, 10)
        batch = seed_batch(11, 20, @commitment_l1_block)

        known_confirmation = insert_confirmation(@stale_confirmation_l1_block)
        mark_confirmed(11..20, known_confirmation)

        new_confirmation_transaction_hash = to_string(transaction_hash())

        new_confirmation_log =
          build_send_root_updated_log(
            rollup_block_hash(blocks_without_batch, 10),
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

        assert :confirmation_missed == discover(json_rpc_named_arguments)

        assert Repo.get_by(LifecycleTransaction, hash: new_confirmation_transaction_hash) == nil

        updated_confirmation = Repo.get_by!(LifecycleTransaction, hash: known_confirmation.hash)
        assert updated_confirmation.id == known_confirmation.id
        assert updated_confirmation.block_number == @confirmation_l1_block
        assert DateTime.to_unix(updated_confirmation.timestamp) == @confirmation_l1_timestamp
        assert confirmed_blocks(updated_confirmation) == Enum.to_list(11..20)

        assert unconfirmed_blocks() == []

        seed_batch_of_blocks(blocks_without_batch, @previous_commitment_l1_block)

        assert :ok == discover(json_rpc_named_arguments)

        new_confirmation = Repo.get_by!(LifecycleTransaction, hash: new_confirmation_transaction_hash)
        assert new_confirmation.block_number == @lower_confirmation_l1_block
        assert confirmed_blocks(new_confirmation) == Enum.to_list(@rollup_first_block..10)

        kept_confirmation = Repo.get_by!(LifecycleTransaction, hash: known_confirmation.hash)
        assert kept_confirmation.block_number == @confirmation_l1_block
        assert confirmed_blocks(kept_confirmation) == Enum.to_list(11..20)

        assert unconfirmed_blocks() == []
      end
    end
  end
end
