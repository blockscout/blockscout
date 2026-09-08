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
    # block to the highest one. Each test of this group calls the first of two
    # confirmations the lower confirmation, and the second one the upper
    # confirmation. When the discovery processes the upper confirmation, the
    # database still shows the rollup blocks of the lower confirmation as
    # unconfirmed.
    #
    # For this reason the parent chain, and not the database, gives the lowest
    # block of the upper confirmation. The lookup range of the upper confirmation
    # ends one block before that confirmation. The range thus holds the log of the
    # lower confirmation while the two events are in different parent chain blocks.
    # The two last tests of this group hold the events of one parent chain block,
    # where this is not true.
    #
    # Each test of this group makes sure that no rollup block belongs to two
    # confirmations.
    describe "perform/5 with two new confirmations" do
      # The database has one batch with the rollup blocks 1..20. No block of it is
      # confirmed.
      #
      # The lower event points to the rollup block 10. The upper event points to
      # the rollup block 20. Both blocks are in the same batch.
      #
      # The lower confirmation covers the blocks 1..10, because the batch starts at
      # the lowest-indexed rollup block. The upper confirmation finds the log of the
      # lower confirmation in its own lookup range. That log points to the block 10,
      # which is in the middle of the batch. As a result, the upper confirmation
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
      # This test is not redundant. The walk of the upper confirmation is the walk of
      # the single-event test "stops at the previous batch when an earlier
      # confirmation covers exactly its last block". In that test the lower log is
      # outside the discovery range. Thus the discovery uses the lower log as a
      # boundary only, and it does not import that log.
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
      # the blocks 11..15 from the second batch. Then it moves one batch down,
      # because the block 11 is the first block of that batch. In the first batch
      # the log of the lower confirmation points to the block 5. As a result, the
      # upper confirmation covers the blocks 6..15, and the blocks 16..20 wait for
      # the next confirmation.
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

      # Both events are new, and both events are in the same parent chain block. One
      # parent chain block can hold two transactions which confirm a node. Then the
      # parent chain gives this state.
      #
      # The database has one batch with the rollup blocks 1..20. No block of it is
      # confirmed. The lower event points to the rollup block 10. The upper event
      # points to the rollup block 20.
      #
      # The lower confirmation must cover the blocks 1..10, and the upper
      # confirmation must cover the blocks 11..20.
      #
      # The lookup range of a confirmation ends one block before the parent chain
      # block of that confirmation. Thus the lookup range of the upper confirmation
      # holds no log of the lower confirmation. The walk continues to the first
      # block of the batch. The lower confirmation then holds the blocks 1..10, and
      # the upper confirmation holds the blocks 1..20. The blocks 1..10 belong to
      # both. One import gets two rows of each of those blocks, and the database
      # stops the import with a cardinality violation.
      #
      # The test "splits one batch between the two confirmations of the inverted order
      # in the same parent chain block" holds the other order of the two logs. The
      # discovery does not read the log index, and it does not read the transaction
      # index. Thus the two runs are the same. The two tests hold the two orders of the
      # logs. Thus a correction which reads the log index must give the correct pair of
      # transactions in each test.
      @tag skip: "Defect: two new confirmations in the same parent chain block"
      test "splits one batch between the two confirmations of the same parent chain block", %{
        json_rpc_named_arguments: json_rpc_named_arguments
      } do
        batch = seed_batch(@rollup_first_block, 20, @commitment_l1_block)

        lower_confirmation_transaction_hash = to_string(transaction_hash())
        upper_confirmation_transaction_hash = to_string(transaction_hash())

        lower_confirmation_log =
          build_send_root_updated_log(
            rollup_block_hash(batch, 10),
            lower_confirmation_transaction_hash,
            @confirmation_l1_block
          )

        upper_confirmation_log =
          build_send_root_updated_log(
            rollup_block_hash(batch, 20),
            upper_confirmation_transaction_hash,
            @confirmation_l1_block,
            log_index: 1,
            transaction_index: 1
          )

        expect_discovery_of([lower_confirmation_log, upper_confirmation_log])

        assert :ok == discover(json_rpc_named_arguments)

        lower_confirmation = Repo.get_by!(LifecycleTransaction, hash: lower_confirmation_transaction_hash)
        upper_confirmation = Repo.get_by!(LifecycleTransaction, hash: upper_confirmation_transaction_hash)

        assert lower_confirmation.id != upper_confirmation.id
        assert lower_confirmation.block_number == @confirmation_l1_block
        assert upper_confirmation.block_number == @confirmation_l1_block

        assert confirmed_blocks(lower_confirmation) == Enum.to_list(@rollup_first_block..10)
        assert confirmed_blocks(upper_confirmation) == Enum.to_list(11..20)
        assert unconfirmed_blocks() == []
      end

      # Both events are new, and both events are in the same parent chain block. The
      # log with the index 0 points to the higher rollup block. Thus the pair holds the
      # inverted order in one parent chain block. A chain which confirms two nodes
      # in one parent chain block can give this order.
      #
      # The database has one batch with the rollup blocks 1..20. No block of it is
      # confirmed. The log with the index 0 points to the rollup block 20. The log with
      # the index 1 points to the rollup block 10.
      #
      # The confirmation of the block 10 must cover the blocks 1..10, and the
      # confirmation of the block 20 must cover the blocks 11..20. Thus the transaction
      # of the log with the index 0 takes the upper blocks. The transaction of the log
      # with the index 1 takes the lower blocks. The test "splits one batch between the
      # two confirmations of the same parent chain block" holds the other order of the
      # two logs. In that test the log with the index 0 takes the lower blocks. The link
      # between the log order and the transactions is what this test holds and no other
      # test holds.
      #
      # The discovery does not read the log index, and it does not read the transaction
      # index. It sorts the confirmations by the number of the rollup block. Thus this
      # run is the same as the run of that other test.
      #
      # The lookup range of a confirmation ends one block before the parent chain block
      # of that confirmation. Therefore no lookup range holds the log of the other
      # confirmation. Each walk continues to the first block of the batch. Thus the
      # blocks 1..10 belong to both confirmations. One import gets two rows of each of
      # those blocks, and the database stops the import with a cardinality violation.
      @tag skip: "Defect: two new confirmations in the same parent chain block"
      test "splits one batch between the two confirmations of the inverted order in the same parent chain block", %{
        json_rpc_named_arguments: json_rpc_named_arguments
      } do
        batch = seed_batch(@rollup_first_block, 20, @commitment_l1_block)

        upper_blocks_transaction_hash = to_string(transaction_hash())
        lower_blocks_transaction_hash = to_string(transaction_hash())

        # The log with the index 0 holds the confirmation of the upper blocks. The log
        # with the index 1 holds the confirmation of the lower blocks.
        upper_blocks_confirmation_log =
          build_send_root_updated_log(
            rollup_block_hash(batch, 20),
            upper_blocks_transaction_hash,
            @confirmation_l1_block
          )

        lower_blocks_confirmation_log =
          build_send_root_updated_log(
            rollup_block_hash(batch, 10),
            lower_blocks_transaction_hash,
            @confirmation_l1_block,
            log_index: 1,
            transaction_index: 1
          )

        expect_discovery_of([upper_blocks_confirmation_log, lower_blocks_confirmation_log])

        assert :ok == discover(json_rpc_named_arguments)

        upper_blocks_confirmation = Repo.get_by!(LifecycleTransaction, hash: upper_blocks_transaction_hash)
        lower_blocks_confirmation = Repo.get_by!(LifecycleTransaction, hash: lower_blocks_transaction_hash)

        assert upper_blocks_confirmation.id != lower_blocks_confirmation.id
        assert upper_blocks_confirmation.block_number == @confirmation_l1_block
        assert lower_blocks_confirmation.block_number == @confirmation_l1_block

        assert confirmed_blocks(lower_blocks_confirmation) == Enum.to_list(@rollup_first_block..10)
        assert confirmed_blocks(upper_blocks_confirmation) == Enum.to_list(11..20)
        assert unconfirmed_blocks() == []
      end

      # Both events are new, and both events are in the same parent chain
      # transaction. One transaction can call the outbox two times. Then the parent
      # chain gives this state. The scenario of two events in the same parent chain
      # block is more wide. The two events of this test also have the same transaction
      # hash.
      #
      # This test is in this group because the parent chain holds two new events. Its
      # result holds one confirmation, and not two, because the database keeps one
      # confirmation per parent chain transaction.
      #
      # The database has one batch with the rollup blocks 1..20. No block of it is
      # confirmed. The lower event points to the rollup block 10. The upper event
      # points to the rollup block 20.
      #
      # The database holds one confirmation per parent chain transaction. Thus the two
      # events must give one confirmation, and that confirmation must hold the rollup
      # blocks 1..20.
      #
      # The discovery examines the two events one after another. It finds no earlier
      # confirmation for each of the two events. The lookup range ends one block
      # before the parent chain block of the events. Thus the lower event gives the
      # blocks 1..10, and the upper event gives the blocks 1..20. One import gets two
      # rows of each block of 1..10, and the database stops the import with a
      # cardinality violation. The two rows of a block hold the same confirmation.
      @tag skip: "Defect: two new confirmations in the same parent chain transaction"
      test "gives all rollup blocks to one confirmation when both events are in the same transaction", %{
        json_rpc_named_arguments: json_rpc_named_arguments
      } do
        batch = seed_batch(@rollup_first_block, 20, @commitment_l1_block)

        confirmation_transaction_hash = to_string(transaction_hash())

        lower_confirmation_log =
          build_send_root_updated_log(
            rollup_block_hash(batch, 10),
            confirmation_transaction_hash,
            @confirmation_l1_block
          )

        upper_confirmation_log =
          build_send_root_updated_log(
            rollup_block_hash(batch, 20),
            confirmation_transaction_hash,
            @confirmation_l1_block,
            log_index: 1
          )

        expect_discovery_of([lower_confirmation_log, upper_confirmation_log])

        assert :ok == discover(json_rpc_named_arguments)

        confirmation = Repo.get_by!(LifecycleTransaction, hash: confirmation_transaction_hash)
        assert confirmation.block_number == @confirmation_l1_block
        assert DateTime.to_unix(confirmation.timestamp) == @confirmation_l1_timestamp

        assert confirmed_blocks(confirmation) == Enum.to_list(@rollup_first_block..20)
        assert unconfirmed_blocks() == []
      end

      # The database has two batches: the blocks 1..10 and the blocks 11..20. No
      # block is confirmed.
      #
      # Both events are new. The event of the older parent chain block points to the
      # rollup block 20. The event of the newer parent chain block points to the
      # rollup block 10. Thus the newer transaction confirms the lower rollup blocks.
      # The HPP mainnet, which is an Arbitrum AnyTrust chain, holds such a pair of
      # confirmations, 3 parent chain blocks apart.
      #
      # The confirmation of the block 10 must cover the blocks 1..10, and the
      # confirmation of the block 20 must cover the blocks 11..20.
      #
      # The lookup range of a confirmation ends one block before the parent chain
      # block of that confirmation. The confirmation of the block 20 is in the older
      # parent chain block. Thus its lookup range holds no log of the confirmation of
      # the block 10. The walk of the confirmation of the block 20 goes down to the
      # first block of the chain. Each of the two confirmations then holds the blocks
      # 1..10. One import gets two rows of each block of 1..10, and the database stops
      # the import with a cardinality violation.
      @tag skip: "Defect: two new confirmations in the inverted order"
      test "splits the batches between the two confirmations of the inverted order", %{
        json_rpc_named_arguments: json_rpc_named_arguments
      } do
        previous_batch = seed_batch(@rollup_first_block, 10, @previous_commitment_l1_block)
        batch = seed_batch(11, 20, @commitment_l1_block)

        lower_blocks_transaction_hash = to_string(transaction_hash())
        upper_blocks_transaction_hash = to_string(transaction_hash())

        # The parent chain holds the confirmation of the upper blocks in the older
        # block, and the confirmation of the lower blocks in the newer block.
        upper_blocks_confirmation_log =
          build_send_root_updated_log(
            rollup_block_hash(batch, 20),
            upper_blocks_transaction_hash,
            @lower_confirmation_l1_block
          )

        lower_blocks_confirmation_log =
          build_send_root_updated_log(
            rollup_block_hash(previous_batch, 10),
            lower_blocks_transaction_hash,
            @confirmation_l1_block
          )

        expect_discovery_of([upper_blocks_confirmation_log, lower_blocks_confirmation_log])

        assert :ok == discover(json_rpc_named_arguments)

        upper_blocks_confirmation = Repo.get_by!(LifecycleTransaction, hash: upper_blocks_transaction_hash)
        assert upper_blocks_confirmation.block_number == @lower_confirmation_l1_block
        assert DateTime.to_unix(upper_blocks_confirmation.timestamp) == @lower_confirmation_l1_timestamp

        lower_blocks_confirmation = Repo.get_by!(LifecycleTransaction, hash: lower_blocks_transaction_hash)
        assert lower_blocks_confirmation.block_number == @confirmation_l1_block
        assert DateTime.to_unix(lower_blocks_confirmation.timestamp) == @confirmation_l1_timestamp

        assert confirmed_blocks(lower_blocks_confirmation) == Enum.to_list(@rollup_first_block..10)
        assert confirmed_blocks(upper_blocks_confirmation) == Enum.to_list(11..20)
        assert unconfirmed_blocks() == []
      end

      # The database has one batch, and that batch holds the rollup blocks 1..10. No
      # block of the batch is confirmed. The rollup blocks 11..20 are also in the
      # database, but no batch of the database holds them. If the indexer did not
      # handle the batch of those blocks, the database has this state.
      #
      # The lower event points to the rollup block 10. The upper event points to the
      # rollup block 20.
      #
      # The discovery finds the number of a rollup block through the batch of that
      # block. The block 20 has no batch. Thus the discovery cannot find the number
      # of that block, and it drops the upper event. The lower confirmation covers
      # the blocks 1..10, and the import writes that confirmation. The return value
      # is `:confirmation_missed`, because the parent chain range holds two events
      # and the import holds one confirmation.
      #
      # The second part of the test makes the change of the indexer: the indexer
      # writes the batch of the blocks 11..20. Then the discovery examines the same
      # parent chain range again. The lower confirmation is a known confirmation of
      # that run, and it keeps its blocks. The lookup range of the upper confirmation
      # holds the log of the lower confirmation. Thus the upper confirmation covers
      # the blocks 11..20, and the import of the lower confirmation alone gives no
      # hole in the confirmation history.
      test "confirms the lower blocks only when the batch of the upper confirmed block is missing", %{
        json_rpc_named_arguments: json_rpc_named_arguments
      } do
        batch = seed_batch(@rollup_first_block, 10, @commitment_l1_block)
        blocks_without_batch = seed_blocks_without_batch(11, 20)

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
            rollup_block_hash(blocks_without_batch, 20),
            upper_confirmation_transaction_hash,
            @confirmation_l1_block
          )

        message_below_lower_confirmation = insert_sent_message_from_l2(5)
        message_above_lower_confirmation = insert_sent_message_from_l2(15)

        expect_discovery_of([lower_confirmation_log, upper_confirmation_log])

        assert :confirmation_missed == discover(json_rpc_named_arguments)

        lower_confirmation = Repo.get_by!(LifecycleTransaction, hash: lower_confirmation_transaction_hash)
        assert lower_confirmation.block_number == @lower_confirmation_l1_block
        assert DateTime.to_unix(lower_confirmation.timestamp) == @lower_confirmation_l1_timestamp

        assert Repo.get_by(LifecycleTransaction, hash: upper_confirmation_transaction_hash) == nil

        assert confirmed_blocks(lower_confirmation) == Enum.to_list(@rollup_first_block..10)

        # `unconfirmed_blocks/0` reads the links of the batches. The blocks 11..20
        # hold no link. Thus this assertion does not cover them.
        assert unconfirmed_blocks() == []

        assert message_status(message_below_lower_confirmation) == :confirmed
        assert message_status(message_above_lower_confirmation) == :sent

        seed_batch_of_blocks(blocks_without_batch, @recent_commitment_l1_block)

        assert :ok == discover(json_rpc_named_arguments)

        upper_confirmation = Repo.get_by!(LifecycleTransaction, hash: upper_confirmation_transaction_hash)
        assert confirmed_blocks(upper_confirmation) == Enum.to_list(11..20)
        assert confirmed_blocks(lower_confirmation) == Enum.to_list(@rollup_first_block..10)
        assert unconfirmed_blocks() == []

        assert message_status(message_above_lower_confirmation) == :confirmed
      end

      # The database has one batch, and that batch holds the rollup blocks 11..20. No
      # block of the batch is confirmed. The rollup blocks 1..10 are also in the
      # database, but no batch of the database holds them. If the indexer did not
      # handle the batch of those blocks, the database has this state.
      #
      # The lower event points to the rollup block 10. The upper event points to the
      # rollup block 20.
      #
      # The discovery finds the number of a rollup block through the batch of that
      # block. The block 10 has no batch. Thus the discovery cannot find the number
      # of that block, and it drops the lower event.
      #
      # The lookup of the upper confirmation examines its own batch. That lookup reads
      # the parent chain from the commitment of the batch to the block before the
      # upper event. That range holds the log of the lower event, and the discovery
      # cannot find the number of the block 10 for that log. Thus the lookup gives an
      # error, and the discovery writes nothing. The return value is
      # `:confirmation_missed`, and the walk to the batch below does not start.
      #
      # The second part of the test makes the change of the indexer: the indexer
      # writes the batch of the blocks 1..10. Then the discovery examines the same
      # parent chain range again, and the two confirmations arrive together.
      test "postpones both confirmations when the batch of the lower confirmed block is missing", %{
        json_rpc_named_arguments: json_rpc_named_arguments
      } do
        blocks_without_batch = seed_blocks_without_batch(@rollup_first_block, 10)
        batch = seed_batch(11, 20, @commitment_l1_block)

        lower_confirmation_transaction_hash = to_string(transaction_hash())
        upper_confirmation_transaction_hash = to_string(transaction_hash())

        lower_confirmation_log =
          build_send_root_updated_log(
            rollup_block_hash(blocks_without_batch, 10),
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

        expect_discovery_of([lower_confirmation_log, upper_confirmation_log])

        assert :confirmation_missed == discover(json_rpc_named_arguments)

        assert Repo.get_by(LifecycleTransaction, hash: lower_confirmation_transaction_hash) == nil
        assert Repo.get_by(LifecycleTransaction, hash: upper_confirmation_transaction_hash) == nil

        assert unconfirmed_blocks() == Enum.to_list(11..20)

        assert message_status(message_below_lower_confirmation) == :sent

        seed_batch_of_blocks(blocks_without_batch, @previous_commitment_l1_block)

        assert :ok == discover(json_rpc_named_arguments)

        lower_confirmation = Repo.get_by!(LifecycleTransaction, hash: lower_confirmation_transaction_hash)
        upper_confirmation = Repo.get_by!(LifecycleTransaction, hash: upper_confirmation_transaction_hash)

        assert confirmed_blocks(lower_confirmation) == Enum.to_list(@rollup_first_block..10)
        assert confirmed_blocks(upper_confirmation) == Enum.to_list(11..20)
        assert unconfirmed_blocks() == []
        assert message_status(message_below_lower_confirmation) == :confirmed
      end

      # The database has two batches: the blocks 1..10 and the blocks 11..20. No
      # block is confirmed. The block 15 is not linked to its batch. If the indexer
      # did not handle the whole batch, the database has this state.
      #
      # The lower event points to the rollup block 10. The upper event points to the
      # rollup block 20.
      #
      # The lower confirmation covers the full first batch. The upper confirmation
      # finds a gap between the blocks 14 and 16. Thus the upper confirmation gives no
      # rollup block.
      #
      # The discovery handles the confirmations of one run in the order of their
      # rollup blocks, from the lowest block to the highest. A confirmation without
      # blocks drops every block which the run collected before it. Therefore the run
      # loses the blocks of the lower confirmation as well, and it writes nothing. The
      # return value is `:confirmation_missed`.
      #
      # The second part of the test makes the change of the indexer: the indexer
      # links the block 15 to its batch. Then the discovery examines the same parent
      # chain range again, and the two confirmations arrive together.
      test "drops the lower confirmation when the upper confirmation finds a gap in its batch", %{
        json_rpc_named_arguments: json_rpc_named_arguments
      } do
        previous_batch = seed_batch(@rollup_first_block, 10, @previous_commitment_l1_block)
        batch = seed_batch(11, 20, @commitment_l1_block, unlinked_blocks: [15])

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

        message_below_lower_confirmation = insert_sent_message_from_l2(5)

        expect_discovery_of([lower_confirmation_log, upper_confirmation_log])

        assert :confirmation_missed == discover(json_rpc_named_arguments)

        assert Repo.get_by(LifecycleTransaction, hash: lower_confirmation_transaction_hash) == nil
        assert Repo.get_by(LifecycleTransaction, hash: upper_confirmation_transaction_hash) == nil

        assert unconfirmed_blocks() == Enum.to_list(@rollup_first_block..14) ++ Enum.to_list(16..20)

        assert message_status(message_below_lower_confirmation) == :sent

        link_blocks_to_batch(batch, [15])

        assert :ok == discover(json_rpc_named_arguments)

        lower_confirmation = Repo.get_by!(LifecycleTransaction, hash: lower_confirmation_transaction_hash)
        upper_confirmation = Repo.get_by!(LifecycleTransaction, hash: upper_confirmation_transaction_hash)

        assert confirmed_blocks(lower_confirmation) == Enum.to_list(@rollup_first_block..10)
        assert confirmed_blocks(upper_confirmation) == Enum.to_list(11..20)
        assert unconfirmed_blocks() == []

        assert message_status(message_below_lower_confirmation) == :confirmed
      end

      # The database has two batches: the blocks 1..10 and the blocks 11..20. No
      # block is confirmed. The block 5 is not linked to its batch. If the indexer did
      # not handle the whole batch, the database has this state.
      #
      # The lower event points to the rollup block 10. The upper event points to the
      # rollup block 20.
      #
      # The lower confirmation finds a gap between the blocks 4 and 6. Thus the lower
      # confirmation gives no rollup block. The upper confirmation walks down to the
      # batch below. The log of the lower confirmation gives the end of that walk.
      # Thus the upper confirmation covers the blocks 11..20, and the run writes that
      # confirmation only. The return value is `:confirmation_missed`.
      #
      # The lower confirmation comes first in the order of the run. Thus its empty
      # result drops nothing, because the run collects the blocks of the upper
      # confirmation after it. The test "drops the lower confirmation when the upper
      # confirmation finds a gap in its batch" holds the other order.
      #
      # The highest confirmed block of the run is the block 20. The discovery marks
      # the messages by the number of that block. Thus the message in the block 5
      # becomes `:confirmed`, although the block 5 stays unconfirmed. The parent chain
      # confirms the block 5 already. Thus this status is correct, and only the link
      # of the block 5 is missing.
      #
      # The second part of the test makes the change of the indexer: the indexer
      # links the block 5 to its batch. Then the discovery examines the same parent
      # chain range again. The upper confirmation is a known confirmation of that
      # run, and it keeps its blocks. The lower confirmation covers the blocks
      # 1..10. The highest confirmed block of that run is the block 10. Thus the
      # message in the block 25 keeps the status `:sent`.
      test "writes the upper confirmation only when the lower confirmation finds a gap in its batch", %{
        json_rpc_named_arguments: json_rpc_named_arguments
      } do
        previous_batch = seed_batch(@rollup_first_block, 10, @previous_commitment_l1_block, unlinked_blocks: [5])
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

        message_below_lower_confirmation = insert_sent_message_from_l2(5)
        message_above_upper_confirmation = insert_sent_message_from_l2(25)

        expect_discovery_of([lower_confirmation_log, upper_confirmation_log])

        assert :confirmation_missed == discover(json_rpc_named_arguments)

        assert Repo.get_by(LifecycleTransaction, hash: lower_confirmation_transaction_hash) == nil

        upper_confirmation = Repo.get_by!(LifecycleTransaction, hash: upper_confirmation_transaction_hash)
        assert upper_confirmation.block_number == @confirmation_l1_block
        assert DateTime.to_unix(upper_confirmation.timestamp) == @confirmation_l1_timestamp

        assert confirmed_blocks(upper_confirmation) == Enum.to_list(11..20)
        assert unconfirmed_blocks() == Enum.to_list(@rollup_first_block..4) ++ Enum.to_list(6..10)

        assert message_status(message_below_lower_confirmation) == :confirmed
        assert message_status(message_above_upper_confirmation) == :sent

        link_blocks_to_batch(previous_batch, [5])

        assert :ok == discover(json_rpc_named_arguments)

        lower_confirmation = Repo.get_by!(LifecycleTransaction, hash: lower_confirmation_transaction_hash)
        assert confirmed_blocks(lower_confirmation) == Enum.to_list(@rollup_first_block..10)
        assert confirmed_blocks(upper_confirmation) == Enum.to_list(11..20)
        assert unconfirmed_blocks() == []

        assert message_status(message_above_upper_confirmation) == :sent
      end
    end
  end
end
