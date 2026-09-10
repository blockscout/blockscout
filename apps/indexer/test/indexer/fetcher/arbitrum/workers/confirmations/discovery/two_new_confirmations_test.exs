# SPDX-License-Identifier: LicenseRef-Blockscout
if Application.get_env(:explorer, :chain_type) == :arbitrum do
  defmodule Indexer.Fetcher.Arbitrum.Workers.Confirmations.Discovery.TwoNewConfirmationsTest do
    use Indexer.Fetcher.Arbitrum.Workers.Confirmations.Discovery.TestCase

    # See `Indexer.Fetcher.Arbitrum.Workers.Confirmations.Discovery.TestCase` for
    # the conventions this suite of files follows.

    # A parent chain range can hold more than one `SendRootUpdated` event. The
    # discovery reads all events of the range in one run. Then it writes the result
    # of the run into the database in one operation.
    #
    # Thus the discovery works on the state of the database from the start of the
    # run. It processes the confirmations one after another, from the lowest rollup
    # block to the highest one. Each test in the groups of two new confirmations
    # calls the first confirmation the lower confirmation. It calls the second
    # confirmation the upper confirmation. When the discovery processes the upper
    # confirmation, the database still shows the rollup blocks of the lower
    # confirmation as unconfirmed.
    #
    # For this reason, the parent chain gives the lowest block of the upper
    # confirmation, not the database. The lookup range of the upper confirmation ends
    # one block before that confirmation. Thus the range holds the log of the lower
    # confirmation. This group holds the scenarios where this is true. In these
    # scenarios, the two events are in two parent chain blocks. The older block holds
    # the confirmation of the lower rollup blocks.
    #
    # The database of this group is complete. Thus these scenarios show how the two
    # confirmations split the rollup blocks between them. Each test makes sure that
    # no rollup block belongs to two confirmations.
    #
    # The group "perform/5 with two new confirmations in one parent chain block or in
    # the inverted order" holds some scenarios. In these scenarios, the lookup range
    # of the upper confirmation holds no log of the other confirmation. The group
    # "perform/5 with two new confirmations and an incomplete database" holds the
    # scenarios where a part of the data of a batch is missing.
    describe "perform/5 with two new confirmations" do
      # The database has one batch with the rollup blocks 1..20. No block of it is
      # confirmed.
      #
      # The lower event points to the rollup block 10. The upper event points to
      # the rollup block 20. Both blocks are in the same batch.
      #
      # Because the batch starts at the lowest-indexed rollup block, the lower
      # confirmation covers the blocks 1..10. The upper confirmation finds the log of
      # the lower confirmation in its own lookup range. That log points to the block
      # 10, which is in the middle of the batch. As a result, the upper confirmation
      # covers the blocks 11..20.
      #
      # The highest confirmed block of the run is the block 20. Thus every L2-to-L1
      # message up to that block becomes `:confirmed`. A message between the two
      # confirmations becomes `:confirmed` as well.
      test "splits one batch between the two confirmations", %{
        json_rpc_named_arguments: json_rpc_named_arguments
      } do
        batch = seed_batch(@rollup_first_block, 20, @commitment_l1_block)

        lower_confirmation_transaction_hash = to_string(transaction_hash())
        upper_confirmation_transaction_hash = to_string(transaction_hash())

        lower_confirmation_log =
          build_send_root_updated_log(
            rollup_block_hash(batch, 10),
            lower_confirmation_transaction_hash,
            @lower_confirmation_l1_block
          )

        upper_confirmation_log =
          build_send_root_updated_log(
            rollup_block_hash(batch, 20),
            upper_confirmation_transaction_hash,
            @confirmation_l1_block
          )

        message_below_lower_confirmation = insert_sent_message_from_l2(5)
        message_between_confirmations = insert_sent_message_from_l2(15)
        message_above_upper_confirmation = insert_sent_message_from_l2(25)

        expect_discovery_of([lower_confirmation_log, upper_confirmation_log])

        assert :ok == discover(json_rpc_named_arguments)

        lower_confirmation = Repo.get_by!(LifecycleTransaction, hash: lower_confirmation_transaction_hash)
        upper_confirmation = Repo.get_by!(LifecycleTransaction, hash: upper_confirmation_transaction_hash)

        assert lower_confirmation.id != upper_confirmation.id
        assert lower_confirmation.block_number == @lower_confirmation_l1_block
        assert DateTime.to_unix(lower_confirmation.timestamp) == @lower_confirmation_l1_timestamp
        assert upper_confirmation.block_number == @confirmation_l1_block
        assert DateTime.to_unix(upper_confirmation.timestamp) == @confirmation_l1_timestamp

        assert confirmed_blocks(lower_confirmation) == Enum.to_list(@rollup_first_block..10)
        assert confirmed_blocks(upper_confirmation) == Enum.to_list(11..20)

        assert message_status(message_below_lower_confirmation) == :confirmed
        assert message_status(message_between_confirmations) == :confirmed
        assert message_status(message_above_upper_confirmation) == :sent
      end

      # The database has two batches: the blocks 1..10 and the blocks 11..20. No
      # block is confirmed.
      #
      # The lower event points to the rollup block 10, which is the last block of
      # the first batch. The upper event points to the rollup block 20, which is the
      # last block of the second batch.
      #
      # The lower confirmation covers the full first batch. The upper confirmation
      # finds no confirmation within the blocks of the second batch. Thus it moves
      # one batch down. In that batch the database still shows the blocks 1..10 as
      # unconfirmed. But the log of the lower confirmation points to the last block
      # of that batch. Thus the walk stops, and the upper confirmation covers the
      # blocks 11..20 only.
      #
      # This test is not redundant. This is also the walk of the single-event test
      # "stops at the previous batch when an earlier confirmation covers exactly its
      # last block". In that test the lower log is outside the discovery range. Thus
      # the discovery uses the lower log as a boundary only, and it does not import
      # that log.
      #
      # In this test the lower log is a confirmation of the same run. Thus the same
      # log must give the boundary of the upper confirmation and a lifecycle
      # transaction of its own. The two confirmations must also split the batches
      # between them.
      test "gives a full batch to each confirmation when both are aligned with a batch boundary", %{
        json_rpc_named_arguments: json_rpc_named_arguments
      } do
        previous_batch = seed_batch(@rollup_first_block, 10, @previous_commitment_l1_block)
        batch = seed_batch(11, 20, @commitment_l1_block)

        lower_confirmation_transaction_hash = to_string(transaction_hash())
        upper_confirmation_transaction_hash = to_string(transaction_hash())

        lower_confirmation_log =
          build_send_root_updated_log(
            rollup_block_hash(previous_batch, 10),
            lower_confirmation_transaction_hash,
            @lower_confirmation_l1_block
          )

        upper_confirmation_log =
          build_send_root_updated_log(
            rollup_block_hash(batch, 20),
            upper_confirmation_transaction_hash,
            @confirmation_l1_block
          )

        expect_discovery_of([lower_confirmation_log, upper_confirmation_log])

        assert :ok == discover(json_rpc_named_arguments)

        lower_confirmation = Repo.get_by!(LifecycleTransaction, hash: lower_confirmation_transaction_hash)
        upper_confirmation = Repo.get_by!(LifecycleTransaction, hash: upper_confirmation_transaction_hash)

        assert confirmed_blocks(lower_confirmation) == Enum.to_list(@rollup_first_block..10)
        assert confirmed_blocks(upper_confirmation) == Enum.to_list(11..20)
        assert unconfirmed_blocks() == []
      end

      # The database has two batches: the blocks 1..10 and the blocks 11..20. No
      # block is confirmed.
      #
      # No event is aligned with a boundary of a batch. The lower event points to
      # the rollup block 5. The upper event points to the rollup block 15.
      #
      # The lower confirmation covers the blocks 1..5. The upper confirmation takes
      # the blocks 11..15 from the second batch. Because the block 11 is the first
      # block of that batch, it then moves one batch down. In the first batch the log
      # of the lower confirmation points to the block 5. As a result, the upper
      # confirmation covers the blocks 6..15, and the blocks 16..20 wait for the next
      # confirmation.
      test "spans the previous batch down to the other confirmation when no confirmation is aligned with a batch", %{
        json_rpc_named_arguments: json_rpc_named_arguments
      } do
        previous_batch = seed_batch(@rollup_first_block, 10, @previous_commitment_l1_block)
        batch = seed_batch(11, 20, @commitment_l1_block)

        lower_confirmation_transaction_hash = to_string(transaction_hash())
        upper_confirmation_transaction_hash = to_string(transaction_hash())

        lower_confirmation_log =
          build_send_root_updated_log(
            rollup_block_hash(previous_batch, 5),
            lower_confirmation_transaction_hash,
            @lower_confirmation_l1_block
          )

        upper_confirmation_log =
          build_send_root_updated_log(
            rollup_block_hash(batch, 15),
            upper_confirmation_transaction_hash,
            @confirmation_l1_block
          )

        expect_discovery_of([lower_confirmation_log, upper_confirmation_log])

        assert :ok == discover(json_rpc_named_arguments)

        lower_confirmation = Repo.get_by!(LifecycleTransaction, hash: lower_confirmation_transaction_hash)
        upper_confirmation = Repo.get_by!(LifecycleTransaction, hash: upper_confirmation_transaction_hash)

        assert confirmed_blocks(lower_confirmation) == Enum.to_list(@rollup_first_block..5)
        assert confirmed_blocks(upper_confirmation) == Enum.to_list(6..15)
        assert unconfirmed_blocks() == Enum.to_list(16..20)
      end

      # The database has two batches: the blocks 1..10 and the blocks 11..20. No block
      # is confirmed.
      #
      # The lower event points to the rollup block 10, which is the last block of the
      # first batch. The upper event points to the rollup block 15, which is in the
      # middle of the second batch.
      #
      # The lower confirmation covers the full first batch. The upper confirmation
      # takes the blocks 11..15 from the second batch. Because the block 11 is the
      # first block of that batch, it then moves one batch down. In the first batch
      # the log of the lower confirmation points to the last block. Thus the walk
      # stops there, and the upper confirmation covers the blocks 11..15 only. The
      # blocks 16..20 wait for the next confirmation.
      #
      # This test holds the pair of a lower event on a batch boundary and an upper
      # event in the middle of a batch. The test "gives a full batch to each
      # confirmation when both are aligned with a batch boundary" holds two events on
      # a boundary. The test "spans the previous batch down to the other confirmation
      # when no confirmation is aligned with a batch" holds two events. Both events
      # are in the middle of a batch.
      test "splits the batches when the lower event is on a batch boundary and the upper event is not", %{
        json_rpc_named_arguments: json_rpc_named_arguments
      } do
        previous_batch = seed_batch(@rollup_first_block, 10, @previous_commitment_l1_block)
        batch = seed_batch(11, 20, @commitment_l1_block)

        lower_confirmation_transaction_hash = to_string(transaction_hash())
        upper_confirmation_transaction_hash = to_string(transaction_hash())

        expect_discovery_of([
          build_send_root_updated_log(
            rollup_block_hash(previous_batch, 10),
            lower_confirmation_transaction_hash,
            @lower_confirmation_l1_block
          ),
          build_send_root_updated_log(
            rollup_block_hash(batch, 15),
            upper_confirmation_transaction_hash,
            @confirmation_l1_block
          )
        ])

        assert :ok == discover(json_rpc_named_arguments)

        lower_confirmation = Repo.get_by!(LifecycleTransaction, hash: lower_confirmation_transaction_hash)
        upper_confirmation = Repo.get_by!(LifecycleTransaction, hash: upper_confirmation_transaction_hash)

        assert confirmed_blocks(lower_confirmation) == Enum.to_list(@rollup_first_block..10)
        assert confirmed_blocks(upper_confirmation) == Enum.to_list(11..15)
        assert unconfirmed_blocks() == Enum.to_list(16..20)
      end

      # The database has two batches: the blocks 1..10 and the blocks 11..20. No block
      # is confirmed.
      #
      # The lower event points to the rollup block 5, which is in the middle of the
      # first batch. The upper event points to the rollup block 20, which is the last
      # block of the second batch.
      #
      # The lower confirmation covers the blocks 1..5. The upper confirmation takes the
      # full second batch and moves one batch down. In the first batch the log of the
      # lower confirmation points to the block 5, which is in the middle of that batch.
      # Thus the upper confirmation covers the blocks 6..20.
      #
      # This test holds the pair of a lower event in the middle of a batch and an
      # upper event on a batch boundary. This test pairs with the test "splits the
      # batches when the lower event is on a batch boundary and the upper event is
      # not". Together they hold the two mixed pairs of this group.
      test "splits the batches when the upper event is on a batch boundary and the lower event is not", %{
        json_rpc_named_arguments: json_rpc_named_arguments
      } do
        previous_batch = seed_batch(@rollup_first_block, 10, @previous_commitment_l1_block)
        batch = seed_batch(11, 20, @commitment_l1_block)

        lower_confirmation_transaction_hash = to_string(transaction_hash())
        upper_confirmation_transaction_hash = to_string(transaction_hash())

        expect_discovery_of([
          build_send_root_updated_log(
            rollup_block_hash(previous_batch, 5),
            lower_confirmation_transaction_hash,
            @lower_confirmation_l1_block
          ),
          build_send_root_updated_log(
            rollup_block_hash(batch, 20),
            upper_confirmation_transaction_hash,
            @confirmation_l1_block
          )
        ])

        assert :ok == discover(json_rpc_named_arguments)

        lower_confirmation = Repo.get_by!(LifecycleTransaction, hash: lower_confirmation_transaction_hash)
        upper_confirmation = Repo.get_by!(LifecycleTransaction, hash: upper_confirmation_transaction_hash)

        assert confirmed_blocks(lower_confirmation) == Enum.to_list(@rollup_first_block..5)
        assert confirmed_blocks(upper_confirmation) == Enum.to_list(6..20)
        assert unconfirmed_blocks() == []
      end
    end
  end
end
