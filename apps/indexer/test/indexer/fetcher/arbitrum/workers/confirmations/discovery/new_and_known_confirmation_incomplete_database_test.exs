# SPDX-License-Identifier: LicenseRef-Blockscout
if Application.get_env(:explorer, :chain_type) == :arbitrum do
  defmodule Indexer.Fetcher.Arbitrum.Workers.Confirmations.Discovery.NewAndKnownConfirmationIncompleteDatabaseTest do
    use Indexer.Fetcher.Arbitrum.Workers.Confirmations.Discovery.TestCase

    # See `Indexer.Fetcher.Arbitrum.Workers.Confirmations.Discovery.TestCase` for
    # the conventions this suite of files follows.

    # A parent chain range can hold a new confirmation together with a known one
    # while the database holds a part of the data which the new confirmation needs.
    # The indexer writes a batch, the links of its rollup blocks and the blocks
    # themselves in several steps, and the discovery can read the parent chain
    # between those steps.
    #
    # The discovery handles the two events apart from each other. Thus a missing part
    # of a batch postpones the new confirmation, and the known confirmation still
    # moves to its new parent chain block in the same run. This group holds the
    # scenarios of both results, and the scenario where the run writes nothing at
    # all.
    #
    # Each test has two parts. The first part gives `:confirmation_missed` for the
    # state of the database. The second part makes the change of the indexer, and it
    # examines the same parent chain range again.
    describe "perform/5 with a new confirmation and a known one over an incomplete database" do
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

      # The database has one batch of the blocks 11..20, and the known confirmation
      # holds those blocks. Its parent chain block and its timestamp are equal to the
      # values in its event, which is in the block 200. The rollup blocks 1..10 are
      # also in the database, but no batch of the database holds them.
      #
      # The new event is in the parent chain block 198, and it points to the rollup
      # block 10. The discovery finds the number of a rollup block through the batch of
      # that block. Thus it cannot find the number of the block 10, and it drops the new
      # event. The known confirmation shows no difference. Therefore the run writes
      # nothing at all, and it returns `:confirmation_missed`.
      #
      # The test "postpones the new confirmation and moves the known one to its new
      # parent chain block" holds the same state of the database with a known
      # confirmation which a re-org moved. There the run writes the known transaction
      # again. This test is the only one where a run of two events writes nothing.
      #
      # The second part of the test makes the change of the indexer: the indexer writes
      # the batch of the blocks 1..10. Then the discovery examines the same parent chain
      # range again. The new confirmation covers the blocks 1..10, and the known
      # confirmation keeps its blocks and its values.
      test "postpones the new confirmation and keeps the known one which did not move", %{
        json_rpc_named_arguments: json_rpc_named_arguments
      } do
        blocks_without_batch = seed_blocks_without_batch(@rollup_first_block, 10)
        batch = seed_batch(11, 20, @commitment_l1_block)

        known_confirmation = insert_confirmation(@confirmation_l1_block, @confirmation_l1_timestamp)
        mark_confirmed(11..20, known_confirmation)

        new_confirmation_transaction_hash = to_string(transaction_hash())

        expect_discovery_of([
          build_send_root_updated_log(
            rollup_block_hash(blocks_without_batch, 10),
            new_confirmation_transaction_hash,
            @lower_confirmation_l1_block
          ),
          build_send_root_updated_log(
            rollup_block_hash(batch, 20),
            to_string(known_confirmation.hash),
            @confirmation_l1_block
          )
        ])

        assert :confirmation_missed == discover(json_rpc_named_arguments)

        assert Repo.get_by(LifecycleTransaction, hash: new_confirmation_transaction_hash) == nil

        kept_confirmation = Repo.get_by!(LifecycleTransaction, hash: known_confirmation.hash)
        assert kept_confirmation.id == known_confirmation.id
        assert kept_confirmation.block_number == @confirmation_l1_block
        assert DateTime.compare(kept_confirmation.timestamp, known_confirmation.timestamp) == :eq
        assert confirmed_blocks(kept_confirmation) == Enum.to_list(11..20)

        assert unconfirmed_blocks() == []

        seed_batch_of_blocks(blocks_without_batch, @previous_commitment_l1_block)

        assert :ok == discover(json_rpc_named_arguments)

        new_confirmation = Repo.get_by!(LifecycleTransaction, hash: new_confirmation_transaction_hash)
        assert new_confirmation.block_number == @lower_confirmation_l1_block
        assert confirmed_blocks(new_confirmation) == Enum.to_list(@rollup_first_block..10)

        assert confirmed_blocks(kept_confirmation) == Enum.to_list(11..20)
        assert unconfirmed_blocks() == []
      end

      # The database has two batches: the blocks 1..10 and the blocks 11..20. The known
      # confirmation holds the full first batch, and a re-org moved it: the database
      # holds the parent chain block 190, and its event is in the block 198. The block
      # 15 of the second batch is not linked to its batch. If the indexer did not handle
      # the whole batch, the database has this state.
      #
      # The new event is in the parent chain block 200, and it points to the rollup
      # block 20. The lookup of the new confirmation finds the log of the known
      # confirmation. That log points to the block 10, which is below the second batch.
      # Thus the discovery takes the block 11 as the start of the range and finds a gap
      # between the blocks 14 and 16. Therefore it writes no block for the new event.
      #
      # The known confirmation still shows a difference. Thus the run writes the new
      # parent chain block and the new timestamp into the known transaction, and it
      # returns `:confirmation_missed` in the same run.
      #
      # The test "postpones the new confirmation and moves the known one to its new
      # parent chain block" holds the same pair of results with an unresolvable rollup
      # block. This test is the only one where a gap of a batch postpones the new
      # confirmation and the known confirmation still moves.
      #
      # The second part of the test makes the change of the indexer: the indexer links
      # the block 15 to its batch. Then the discovery examines the same parent chain
      # range again. The new confirmation covers the blocks 11..20, and the walk stops
      # at the first batch, which is confirmed in full. The known confirmation shows no
      # difference any more.
      test "postpones the new confirmation on a gap and moves the known one to its new parent chain block", %{
        json_rpc_named_arguments: json_rpc_named_arguments
      } do
        previous_batch = seed_batch(@rollup_first_block, 10, @previous_commitment_l1_block)
        batch = seed_batch(11, 20, @commitment_l1_block, unlinked_blocks: [15])

        known_confirmation = insert_confirmation(@stale_confirmation_l1_block)
        mark_confirmed(@rollup_first_block..10, known_confirmation)

        new_confirmation_transaction_hash = to_string(transaction_hash())

        expect_discovery_of([
          build_send_root_updated_log(
            rollup_block_hash(previous_batch, 10),
            to_string(known_confirmation.hash),
            @lower_confirmation_l1_block
          ),
          build_send_root_updated_log(
            rollup_block_hash(batch, 20),
            new_confirmation_transaction_hash,
            @confirmation_l1_block
          )
        ])

        assert :confirmation_missed == discover(json_rpc_named_arguments)

        assert Repo.get_by(LifecycleTransaction, hash: new_confirmation_transaction_hash) == nil

        updated_confirmation = Repo.get_by!(LifecycleTransaction, hash: known_confirmation.hash)
        assert updated_confirmation.id == known_confirmation.id
        assert updated_confirmation.block_number == @lower_confirmation_l1_block
        assert DateTime.to_unix(updated_confirmation.timestamp) == @lower_confirmation_l1_timestamp
        assert confirmed_blocks(updated_confirmation) == Enum.to_list(@rollup_first_block..10)

        assert unconfirmed_blocks() == Enum.to_list(11..14) ++ Enum.to_list(16..20)

        link_blocks_to_batch(batch, [15])

        assert :ok == discover(json_rpc_named_arguments)

        new_confirmation = Repo.get_by!(LifecycleTransaction, hash: new_confirmation_transaction_hash)
        assert new_confirmation.block_number == @confirmation_l1_block
        assert confirmed_blocks(new_confirmation) == Enum.to_list(11..20)

        kept_confirmation = Repo.get_by!(LifecycleTransaction, hash: known_confirmation.hash)
        assert kept_confirmation.block_number == @lower_confirmation_l1_block
        assert confirmed_blocks(kept_confirmation) == Enum.to_list(@rollup_first_block..10)

        assert unconfirmed_blocks() == []
      end
    end
  end
end
