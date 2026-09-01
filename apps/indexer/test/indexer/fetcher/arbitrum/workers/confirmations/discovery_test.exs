# SPDX-License-Identifier: LicenseRef-Blockscout
if Application.get_env(:explorer, :chain_type) == :arbitrum do
  defmodule Indexer.Fetcher.Arbitrum.Workers.Confirmations.DiscoveryTest do
    use EthereumJSONRPC.Case, async: false
    use Explorer.DataCase

    import EthereumJSONRPC, only: [integer_to_quantity: 1, quantity_to_integer: 1]
    import Mox

    alias EthereumJSONRPC.Arbitrum.Constants.Events, as: ArbitrumEvents
    alias Explorer.Chain.Arbitrum.BatchBlock
    alias Explorer.Chain.Arbitrum.LifecycleTransaction
    alias Explorer.Chain.Arbitrum.Message
    alias Explorer.Repo
    alias Indexer.Fetcher.Arbitrum.Workers.Confirmations.Discovery

    @outbox_address "0x0b9857ae2d4a3dbe74ffe1d7df045bb7f96e4840"

    # Bound at compile time so that it can be matched in the `eth_getLogs` clause
    # of the mock: a pattern cannot call a function.
    @send_root_updated_topic ArbitrumEvents.send_root_updated()

    # One call of `perform/5` reads the logs of this parent chain range. The
    # `SendRootUpdated` event of each test is in the parent chain block 200.
    @discovery_l1_start_block 195
    @discovery_l1_end_block 205
    @confirmation_l1_block 200
    @confirmation_l1_timestamp 1_700_000_000

    # One parent chain range can hold two `SendRootUpdated` events. The lower
    # confirmation confirms the lower rollup blocks. Thus the parent chain holds it
    # in an older block than the upper confirmation. The upper confirmation is the
    # confirmation which every test of a single event uses.
    @lower_confirmation_l1_block 198
    @lower_confirmation_l1_timestamp @confirmation_l1_timestamp - 24

    # This is the parent chain block which the database holds for a confirmation
    # that a re-org moved. This block is less than the parent chain block of each
    # event. Thus the discovery always finds a difference and writes such a
    # transaction again.
    @stale_confirmation_l1_block 190

    # Wide enough to keep every parent chain lookup of the batch walk within one
    # `eth_getLogs` request. One test passes the narrow range instead, to make the
    # discovery read the same lookups in several chunks.
    @logs_block_range 1000
    @narrow_logs_block_range 50

    # The parent chain block of a confirmation which happened before the one under
    # discovery. This block is between the commitments of the batches and the
    # confirmation under discovery, thus the discovery can find that earlier
    # confirmation. The test of the re-link also puts a stale link to this block,
    # for a transaction which the discovery does not find on the parent chain.
    @earlier_confirmation_l1_block 150

    # The parent chain blocks of the commitment transactions of the batches. The
    # first one belongs to the batch with the confirmed block. The other ones
    # belong to the batches below it.
    @commitment_l1_block 100
    @previous_commitment_l1_block 90
    @oldest_commitment_l1_block 80

    # The lowest indexed rollup block. The oldest batch of each test starts here.
    # Thus the discovery cannot move below this block.
    @rollup_first_block 1

    setup :verify_on_exit!

    setup %{json_rpc_named_arguments: json_rpc_named_arguments} do
      mocked_json_rpc_named_arguments = Keyword.put(json_rpc_named_arguments, :transport, EthereumJSONRPC.Mox)

      %{json_rpc_named_arguments: mocked_json_rpc_named_arguments}
    end

    # What this file covers
    #
    # The tests describe the scenarios which the discovery must handle. They do not
    # describe the branches of its code. One scenario has three parts:
    #   - one state of the database
    #   - one set of `SendRootUpdated` events of a parent chain range
    #   - the result which the discovery must produce
    #
    # The `describe` blocks group the scenarios by the set of events:
    #   - one new confirmation
    #   - one confirmation which the database knows already
    #   - two new confirmations
    #   - a new confirmation together with a known one
    #   - two known confirmations
    #
    # Even when another test already runs the same branches of the code, a scenario
    # keeps its test. There are two reasons:
    #   - the file must show the whole matrix of the expected states. A missing
    #     scenario tells the reader that the discovery does not support that state.
    #   - a change of the code can break a scenario of two confirmations and keep
    #     the scenario of a single one. Thus one test cannot replace the other.
    #
    # A test which runs no branch of its own carries a remark. The remark names what
    # the test holds and no other test holds.

    # A `SendRootUpdated` event on the parent chain confirms one rollup block. The
    # event also confirms all rollup blocks below that block, down to the block of
    # the confirmation before it.
    #
    # Each test in this group gives the discovery one such event. The parent chain
    # transaction of the event is not in the database yet. Thus the discovery must
    # find all rollup blocks that belong to this confirmation.
    #
    # The discovery starts with the batch that contains the confirmed block. Then it
    # can move down, from batch to batch. The walk stops on one of these conditions:
    #   - the discovery finds an earlier confirmation inside the batch
    #   - all blocks of the batch below are confirmed already
    #   - the batch starts at the lowest indexed rollup block
    #
    # To find an earlier confirmation, the discovery reads the parent chain logs
    # between the commitment of the batch and the confirmation under discovery.
    describe "perform/5 with a new confirmation" do
      # The database has one batch with the rollup blocks 1..10. No block of it is
      # confirmed.
      #
      # The event points to the rollup block 10, which is the highest block of the
      # batch. No earlier confirmation exists on the parent chain. The batch starts
      # at the lowest indexed rollup block. As a result, the confirmation covers the
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

        expect_discovery(rollup_block_hash(batch, 10), confirmation_transaction_hash, %{
          # The range between the commitment of the batch and the confirmation.
          # It contains no earlier confirmation.
          {@commitment_l1_block, @confirmation_l1_block - 1} => []
        })

        assert :ok == discover(json_rpc_named_arguments)

        assert drain_get_logs_ranges() == [
                 {@discovery_l1_start_block, @discovery_l1_end_block},
                 {@commitment_l1_block, @confirmation_l1_block - 1}
               ]

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

        expect_discovery(rollup_block_hash(batch, 7), confirmation_transaction_hash, %{
          {@commitment_l1_block, @confirmation_l1_block - 1} => []
        })

        assert :ok == discover(json_rpc_named_arguments)

        assert drain_get_logs_ranges() == [
                 {@discovery_l1_start_block, @discovery_l1_end_block},
                 {@commitment_l1_block, @confirmation_l1_block - 1}
               ]

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

        expect_discovery(rollup_block_hash(batch, 10), confirmation_transaction_hash, %{
          {@commitment_l1_block, @confirmation_l1_block - 1} => [
            build_send_root_updated_log(
              rollup_block_hash(batch, 5),
              to_string(earlier_confirmation.hash),
              @earlier_confirmation_l1_block
            )
          ]
        })

        assert :ok == discover(json_rpc_named_arguments)

        # The walk stops inside the batch, thus no other range is requested.
        assert drain_get_logs_ranges() == [
                 {@discovery_l1_start_block, @discovery_l1_end_block},
                 {@commitment_l1_block, @confirmation_l1_block - 1}
               ]

        confirmation = Repo.get_by!(LifecycleTransaction, hash: confirmation_transaction_hash)
        assert confirmed_blocks(confirmation) == Enum.to_list(6..10)
        assert confirmed_blocks(earlier_confirmation) == Enum.to_list(@rollup_first_block..5)
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

        expect_discovery(rollup_block_hash(batch, 20), confirmation_transaction_hash, %{
          {@commitment_l1_block, @confirmation_l1_block - 1} => []
        })

        assert :ok == discover(json_rpc_named_arguments)

        # The database alone shows that the first batch is confirmed. Thus the
        # discovery requests no logs for the range of that batch.
        assert drain_get_logs_ranges() == [
                 {@discovery_l1_start_block, @discovery_l1_end_block},
                 {@commitment_l1_block, @confirmation_l1_block - 1}
               ]

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

        expect_discovery(rollup_block_hash(batch, 20), confirmation_transaction_hash, %{
          # The range of the second batch, then the range of the first batch.
          {@commitment_l1_block, @confirmation_l1_block - 1} => [earlier_confirmation_log],
          {@previous_commitment_l1_block, @confirmation_l1_block - 1} => [earlier_confirmation_log]
        })

        assert :ok == discover(json_rpc_named_arguments)

        assert drain_get_logs_ranges() == [
                 {@discovery_l1_start_block, @discovery_l1_end_block},
                 {@commitment_l1_block, @confirmation_l1_block - 1},
                 {@previous_commitment_l1_block, @confirmation_l1_block - 1}
               ]

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

        expect_discovery(rollup_block_hash(batch, 20), confirmation_transaction_hash, %{
          {@commitment_l1_block, @confirmation_l1_block - 1} => [earlier_confirmation_log],
          {@previous_commitment_l1_block, @confirmation_l1_block - 1} => [earlier_confirmation_log]
        })

        assert :ok == discover(json_rpc_named_arguments)

        assert drain_get_logs_ranges() == [
                 {@discovery_l1_start_block, @discovery_l1_end_block},
                 {@commitment_l1_block, @confirmation_l1_block - 1},
                 {@previous_commitment_l1_block, @confirmation_l1_block - 1}
               ]

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
      # confirmation in the range of each batch. Thus it moves down from batch to
      # batch. The first batch starts at the lowest indexed rollup block. As a
      # result, the walk stops there, and the confirmation covers the blocks 1..15.
      test "walks back through several batches until the lowest indexed rollup block", %{
        json_rpc_named_arguments: json_rpc_named_arguments
      } do
        seed_batch(@rollup_first_block, 5, @oldest_commitment_l1_block)
        seed_batch(6, 10, @previous_commitment_l1_block)
        batch = seed_batch(11, 15, @commitment_l1_block)

        confirmation_transaction_hash = to_string(transaction_hash())

        expect_discovery(rollup_block_hash(batch, 15), confirmation_transaction_hash, %{
          # No range contains an earlier confirmation. Thus the walk continues
          # down to the lowest indexed rollup block.
          {@commitment_l1_block, @confirmation_l1_block - 1} => [],
          {@previous_commitment_l1_block, @confirmation_l1_block - 1} => [],
          {@oldest_commitment_l1_block, @confirmation_l1_block - 1} => []
        })

        assert :ok == discover(json_rpc_named_arguments)

        assert drain_get_logs_ranges() == [
                 {@discovery_l1_start_block, @discovery_l1_end_block},
                 {@commitment_l1_block, @confirmation_l1_block - 1},
                 {@previous_commitment_l1_block, @confirmation_l1_block - 1},
                 {@oldest_commitment_l1_block, @confirmation_l1_block - 1}
               ]

        confirmation = Repo.get_by!(LifecycleTransaction, hash: confirmation_transaction_hash)
        assert confirmed_blocks(confirmation) == Enum.to_list(@rollup_first_block..15)
      end

      # The database has two batches: the blocks 1..10 and the blocks 11..20. No
      # block is confirmed, and no earlier confirmation exists on the parent chain.
      #
      # The parent chain range of each batch is wider than the maximum range of one
      # `eth_getLogs` request. Thus the discovery reads such a range in chunks, from
      # the newest chunk to the oldest one. The chunks of the second batch, which
      # was committed in the block 100, are 150..199 and 100..149. The chunks of the
      # first batch, which was committed in the block 90, are the same two plus
      # 90..99. The discovery keeps the logs of the chunks it already read, thus it
      # requests each chunk only once.
      test "reads a wide parent chain range in chunks and requests a repeated chunk only once", %{
        json_rpc_named_arguments: json_rpc_named_arguments
      } do
        seed_batch(@rollup_first_block, 10, @previous_commitment_l1_block)
        batch = seed_batch(11, 20, @commitment_l1_block)

        confirmation_transaction_hash = to_string(transaction_hash())

        expect_discovery(rollup_block_hash(batch, 20), confirmation_transaction_hash, %{
          {150, @confirmation_l1_block - 1} => [],
          {@commitment_l1_block, 149} => [],
          {@previous_commitment_l1_block, 99} => []
        })

        assert :ok == discover(json_rpc_named_arguments, @narrow_logs_block_range)

        # Each chunk appears once. The chunks 150..199 and 100..149 belong to the
        # ranges of both batches, and the walk to the first batch reuses the logs
        # which the second batch read already.
        assert drain_get_logs_ranges() == [
                 {@discovery_l1_start_block, @discovery_l1_end_block},
                 {150, @confirmation_l1_block - 1},
                 {@commitment_l1_block, 149},
                 {@previous_commitment_l1_block, 99}
               ]

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

        expect_discovery(rollup_block_hash(batch, 10), confirmation_transaction_hash, %{
          {@commitment_l1_block, @confirmation_l1_block - 1} => []
        })

        assert :ok == discover(json_rpc_named_arguments)

        assert drain_get_logs_ranges() == [
                 {@discovery_l1_start_block, @discovery_l1_end_block},
                 {@commitment_l1_block, @confirmation_l1_block - 1}
               ]

        # The full batch is linked to the new confirmation. The other transaction
        # keeps no block.
        confirmation = Repo.get_by!(LifecycleTransaction, hash: confirmation_transaction_hash)
        assert confirmed_blocks(confirmation) == Enum.to_list(@rollup_first_block..10)
        assert confirmed_blocks(wrong_confirmation) == []
      end
    end

    # The parent chain transaction of the event is in the database already, as a
    # lifecycle transaction. Thus the rollup blocks of this confirmation are linked
    # to it already.
    #
    # In this condition the discovery does not examine the rollup blocks one more
    # time. It only compares the parent chain block number and the timestamp of the
    # known transaction with the values from the event. A difference between them
    # can occur after a re-org.
    describe "perform/5 with an already known confirmation" do
      # The database has one batch with the rollup blocks 1..10, and no block of it
      # is confirmed. The lifecycle transaction of the confirmation is in the
      # database with the parent chain block 190.
      #
      # The event shows the same transaction in the parent chain block 200, because
      # a re-org moved it. Thus the discovery writes the new block number and the
      # new timestamp into the same record. The rollup blocks stay as they are, and
      # the discovery asks for no more logs.
      test "updates the confirmation transaction when its parent chain block changed", %{
        json_rpc_named_arguments: json_rpc_named_arguments
      } do
        batch = seed_batch(@rollup_first_block, 10, @commitment_l1_block)

        existing_confirmation = insert_confirmation(@stale_confirmation_l1_block)

        expect_discovery(rollup_block_hash(batch, 10), to_string(existing_confirmation.hash))

        assert :ok == discover(json_rpc_named_arguments)

        # The discovery does not look for an earlier confirmation.
        assert drain_get_logs_ranges() == [{@discovery_l1_start_block, @discovery_l1_end_block}]

        updated_confirmation = Repo.get_by!(LifecycleTransaction, hash: existing_confirmation.hash)
        assert updated_confirmation.id == existing_confirmation.id
        assert updated_confirmation.block_number == @confirmation_l1_block
        assert DateTime.to_unix(updated_confirmation.timestamp) == @confirmation_l1_timestamp
        assert updated_confirmation.status == existing_confirmation.status

        assert unconfirmed_blocks() == Enum.to_list(@rollup_first_block..10)
      end

      # The lifecycle transaction of the confirmation is in the database. Its parent
      # chain block number and its timestamp are equal to the values in the event.
      #
      # The discovery finds no difference, thus it writes nothing and the result is
      # `:ok`. This is the usual result when the same parent chain range is
      # processed one more time.
      test "leaves the confirmation transaction untouched when nothing changed", %{
        json_rpc_named_arguments: json_rpc_named_arguments
      } do
        existing_confirmation = insert_confirmation(@confirmation_l1_block, @confirmation_l1_timestamp)

        expect_discovery(to_string(block_hash()), to_string(existing_confirmation.hash))

        assert :ok == discover(json_rpc_named_arguments)

        assert drain_get_logs_ranges() == [{@discovery_l1_start_block, @discovery_l1_end_block}]

        assert Repo.aggregate(LifecycleTransaction, :count) == 1

        kept_confirmation = Repo.get_by!(LifecycleTransaction, hash: existing_confirmation.hash)
        assert kept_confirmation.id == existing_confirmation.id
        assert kept_confirmation.block_number == @confirmation_l1_block
        assert DateTime.compare(kept_confirmation.timestamp, existing_confirmation.timestamp) == :eq
        assert kept_confirmation.status == existing_confirmation.status
      end
    end

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
    # ends one block before that confirmation. Thus the range holds the log of the
    # lower confirmation. Each test of this group makes sure that the two
    # confirmations do not take the same rollup blocks.
    describe "perform/5 with two new confirmations" do
      # The database has one batch with the rollup blocks 1..20. No block of it is
      # confirmed.
      #
      # The lower event points to the rollup block 10. The upper event points to
      # the rollup block 20. Both blocks are in the same batch.
      #
      # The lower confirmation covers the blocks 1..10, because the batch starts at
      # the lowest indexed rollup block. The upper confirmation finds the log of the
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

        expect_discovery_of(
          [lower_confirmation_log, upper_confirmation_log],
          %{
            # The range of the lower confirmation ends before the block of that
            # confirmation. Thus the range holds no confirmation.
            {@commitment_l1_block, @lower_confirmation_l1_block - 1} => [],
            # The range of the upper confirmation ends after the block of the
            # lower confirmation. Thus the range holds the log of that
            # confirmation.
            {@commitment_l1_block, @confirmation_l1_block - 1} => [lower_confirmation_log]
          }
        )

        assert :ok == discover(json_rpc_named_arguments)

        # The discovery examines the lower confirmation first. Thus the shorter
        # range comes first. The two ranges are different. Thus the discovery
        # cannot use the kept logs of the first range for the second range.
        assert drain_get_logs_ranges() == [
                 {@discovery_l1_start_block, @discovery_l1_end_block},
                 {@commitment_l1_block, @lower_confirmation_l1_block - 1},
                 {@commitment_l1_block, @confirmation_l1_block - 1}
               ]

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

        expect_discovery_of(
          [lower_confirmation_log, upper_confirmation_log],
          %{
            # The lower confirmation reads the range of the first batch.
            {@previous_commitment_l1_block, @lower_confirmation_l1_block - 1} => [],
            # The upper confirmation reads the range of the second batch, then
            # the range of the first batch. The log of the lower confirmation
            # points to a rollup block with a number less than the first block of
            # the second batch. Thus the walk continues to the first batch.
            {@commitment_l1_block, @confirmation_l1_block - 1} => [lower_confirmation_log],
            {@previous_commitment_l1_block, @confirmation_l1_block - 1} => [lower_confirmation_log]
          }
        )

        assert :ok == discover(json_rpc_named_arguments)

        assert drain_get_logs_ranges() == [
                 {@discovery_l1_start_block, @discovery_l1_end_block},
                 {@previous_commitment_l1_block, @lower_confirmation_l1_block - 1},
                 {@commitment_l1_block, @confirmation_l1_block - 1},
                 {@previous_commitment_l1_block, @confirmation_l1_block - 1}
               ]

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

        expect_discovery_of(
          [lower_confirmation_log, upper_confirmation_log],
          %{
            {@previous_commitment_l1_block, @lower_confirmation_l1_block - 1} => [],
            {@commitment_l1_block, @confirmation_l1_block - 1} => [lower_confirmation_log],
            {@previous_commitment_l1_block, @confirmation_l1_block - 1} => [lower_confirmation_log]
          }
        )

        assert :ok == discover(json_rpc_named_arguments)

        assert drain_get_logs_ranges() == [
                 {@discovery_l1_start_block, @discovery_l1_end_block},
                 {@previous_commitment_l1_block, @lower_confirmation_l1_block - 1},
                 {@commitment_l1_block, @confirmation_l1_block - 1},
                 {@previous_commitment_l1_block, @confirmation_l1_block - 1}
               ]

        lower_confirmation = Repo.get_by!(LifecycleTransaction, hash: lower_confirmation_transaction_hash)
        upper_confirmation = Repo.get_by!(LifecycleTransaction, hash: upper_confirmation_transaction_hash)

        assert confirmed_blocks(lower_confirmation) == Enum.to_list(@rollup_first_block..5)
        assert confirmed_blocks(upper_confirmation) == Enum.to_list(6..15)
        assert unconfirmed_blocks() == Enum.to_list(16..20)
      end
    end

    # A parent chain range can hold one new confirmation together with a
    # confirmation which the database knows already. The discovery examines the
    # rollup blocks of the new confirmation only. For the known confirmation it
    # compares the parent chain block number and the timestamp with the values of
    # the event. If the values are different, the discovery writes the known
    # transaction again.
    #
    # Both results go into the database in the same operation.
    describe "perform/5 with a new confirmation and an already known one" do
      # The database has two batches: the blocks 1..10 and the blocks 11..20. The
      # known confirmation holds the blocks 1..10 already. The parent chain block
      # number and the timestamp of that confirmation are equal to the values in
      # its event.
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

        expect_discovery_of(
          [known_confirmation_log, new_confirmation_log],
          %{{@commitment_l1_block, @confirmation_l1_block - 1} => [known_confirmation_log]}
        )

        assert :ok == discover(json_rpc_named_arguments)

        # The database alone stops the walk at the first batch. Thus the list
        # holds no range of that batch.
        assert drain_get_logs_ranges() == [
                 {@discovery_l1_start_block, @discovery_l1_end_block},
                 {@commitment_l1_block, @confirmation_l1_block - 1}
               ]

        # The discovery asks for the timestamp of the block of each event in one
        # request.
        assert drain_block_number_batches() == [[@lower_confirmation_l1_block, @confirmation_l1_block]]

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

        expect_discovery_of(
          [known_confirmation_log, new_confirmation_log],
          %{
            # The range of the second batch. The log points to a block with a
            # number less than the first block of that batch. Thus the walk
            # continues.
            {@commitment_l1_block, @confirmation_l1_block - 1} => [known_confirmation_log],
            # The range of the first batch. The same log ends the walk here.
            {@previous_commitment_l1_block, @confirmation_l1_block - 1} => [known_confirmation_log]
          }
        )

        assert :ok == discover(json_rpc_named_arguments)

        assert drain_get_logs_ranges() == [
                 {@discovery_l1_start_block, @discovery_l1_end_block},
                 {@commitment_l1_block, @confirmation_l1_block - 1},
                 {@previous_commitment_l1_block, @confirmation_l1_block - 1}
               ]

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

        expect_discovery_of(
          [known_confirmation_log, new_confirmation_log],
          %{{@commitment_l1_block, @confirmation_l1_block - 1} => [known_confirmation_log]}
        )

        assert :ok == discover(json_rpc_named_arguments)

        assert drain_get_logs_ranges() == [
                 {@discovery_l1_start_block, @discovery_l1_end_block},
                 {@commitment_l1_block, @confirmation_l1_block - 1}
               ]

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
    end

    # The database can know both confirmations of the range already. Then the
    # discovery examines no rollup block, and it reads no more logs. It compares
    # the parent chain block number and the timestamp of each known transaction
    # with the values of its event. It writes only the transactions which show a
    # difference.
    describe "perform/5 with two already known confirmations" do
      # The database has one batch with the rollup blocks 1..10, and no block of it
      # is confirmed. Both confirmations of the range are in the database.
      #
      # A re-org moved the first confirmation. The database holds the parent chain
      # block 190, but the event of the confirmation is in the block 198. The
      # second confirmation shows the same values as its event.
      #
      # Thus the discovery writes the first transaction only. The second transaction
      # and all rollup blocks stay as they are.
      #
      # Both events point to a rollup block of the batch. A walk of the batch reads
      # the parent chain range of the commitment. The mock has no response for that
      # range, thus it fails. This is the proof that the discovery examines no rollup
      # block. With an unresolvable block hash, the walk ends quietly and the test
      # shows nothing.
      test "updates the confirmation which moved and keeps the other one", %{
        json_rpc_named_arguments: json_rpc_named_arguments
      } do
        batch = seed_batch(@rollup_first_block, 10, @commitment_l1_block)

        moved_confirmation = insert_confirmation(@stale_confirmation_l1_block)
        kept_confirmation = insert_confirmation(@confirmation_l1_block, @confirmation_l1_timestamp)

        expect_discovery_of([
          build_send_root_updated_log(
            rollup_block_hash(batch, 5),
            to_string(moved_confirmation.hash),
            @lower_confirmation_l1_block
          ),
          build_send_root_updated_log(
            rollup_block_hash(batch, 10),
            to_string(kept_confirmation.hash),
            @confirmation_l1_block
          )
        ])

        assert :ok == discover(json_rpc_named_arguments)

        # The discovery looks for no earlier confirmation, because it examines no
        # rollup block.
        assert drain_get_logs_ranges() == [{@discovery_l1_start_block, @discovery_l1_end_block}]
        assert drain_block_number_batches() == [[@lower_confirmation_l1_block, @confirmation_l1_block]]

        updated_confirmation = Repo.get_by!(LifecycleTransaction, hash: moved_confirmation.hash)
        assert updated_confirmation.id == moved_confirmation.id
        assert updated_confirmation.block_number == @lower_confirmation_l1_block
        assert DateTime.to_unix(updated_confirmation.timestamp) == @lower_confirmation_l1_timestamp

        untouched_confirmation = Repo.get_by!(LifecycleTransaction, hash: kept_confirmation.hash)
        assert untouched_confirmation.id == kept_confirmation.id
        assert untouched_confirmation.block_number == @confirmation_l1_block
        assert DateTime.compare(untouched_confirmation.timestamp, kept_confirmation.timestamp) == :eq

        assert unconfirmed_blocks() == Enum.to_list(@rollup_first_block..10)
      end

      # Both confirmations of the range are in the database, and the values of both
      # are equal to the values of their events. When the discovery reads the same
      # parent chain range one more time, it finds this condition. This condition is
      # the usual state of a production chain. Every iteration of the discovery reads
      # a range which overlaps the previous one.
      #
      # The discovery finds no difference. Thus it writes nothing, and the result
      # is `:ok`.
      #
      # This test is not redundant. The test "updates the confirmation which moved
      # and keeps the other one" runs the same branches. But this test is the only
      # one of the groups with two events which counts the rows of
      # `LifecycleTransaction`.
      #
      # The count is exact here, because the test seeds no batch. Thus the count
      # shows that neither of the two known events adds a row. The other test seeds a
      # batch, and `seed_batch/3` leaves lifecycle transactions of its own. Thus a
      # count there gives no information.
      #
      # For the same reason the events here point to block hashes outside the
      # database. A batch breaks the exact count. The other test already shows that
      # the discovery walks no batch.
      test "leaves both confirmation transactions untouched when nothing changed", %{
        json_rpc_named_arguments: json_rpc_named_arguments
      } do
        lower_confirmation = insert_confirmation(@lower_confirmation_l1_block, @lower_confirmation_l1_timestamp)
        upper_confirmation = insert_confirmation(@confirmation_l1_block, @confirmation_l1_timestamp)

        expect_discovery_of([
          build_send_root_updated_log(
            to_string(block_hash()),
            to_string(lower_confirmation.hash),
            @lower_confirmation_l1_block
          ),
          build_send_root_updated_log(
            to_string(block_hash()),
            to_string(upper_confirmation.hash),
            @confirmation_l1_block
          )
        ])

        assert :ok == discover(json_rpc_named_arguments)

        assert drain_get_logs_ranges() == [{@discovery_l1_start_block, @discovery_l1_end_block}]
        assert drain_block_number_batches() == [[@lower_confirmation_l1_block, @confirmation_l1_block]]

        # This test seeds no batch. Thus the database holds the two confirmations
        # only.
        assert Repo.aggregate(LifecycleTransaction, :count) == 2

        kept_lower_confirmation = Repo.get_by!(LifecycleTransaction, hash: lower_confirmation.hash)
        assert kept_lower_confirmation.id == lower_confirmation.id
        assert kept_lower_confirmation.block_number == @lower_confirmation_l1_block
        assert DateTime.compare(kept_lower_confirmation.timestamp, lower_confirmation.timestamp) == :eq
        assert kept_lower_confirmation.status == lower_confirmation.status

        kept_upper_confirmation = Repo.get_by!(LifecycleTransaction, hash: upper_confirmation.hash)
        assert kept_upper_confirmation.id == upper_confirmation.id
        assert kept_upper_confirmation.block_number == @confirmation_l1_block
        assert DateTime.compare(kept_upper_confirmation.timestamp, upper_confirmation.timestamp) == :eq
        assert kept_upper_confirmation.status == upper_confirmation.status
      end
    end

    # Runs the discovery over the parent chain range holding the confirmation.
    defp discover(json_rpc_named_arguments, logs_block_range \\ @logs_block_range) do
      Discovery.perform(
        @outbox_address,
        @discovery_l1_start_block,
        @discovery_l1_end_block,
        %{
          json_rpc_named_arguments: json_rpc_named_arguments,
          logs_block_range: logs_block_range,
          chunk_size: 10,
          track_finalization: true,
          finalized_confirmations: true
        },
        @rollup_first_block
      )
    end

    # Inserts a batch with its commitment transaction and the rollup blocks
    # belonging to it, all of them unconfirmed (`confirmation_id` is `nil`).
    # Returns the batch together with the inserted blocks keyed by block number.
    #
    # Note: `arbitrum_l1_batch_factory` inserts a lifecycle transaction of its own
    # before the `commitment_id` override is applied. Thus each call leaves one
    # unused lifecycle transaction in the database, and a count of the rows of
    # `LifecycleTransaction` is not a usable assertion in a test which seeds a
    # batch. Look the transaction up by its hash instead.
    defp seed_batch(start_block, end_block, commitment_l1_block) do
      commitment_transaction = insert(:arbitrum_lifecycle_transaction, block_number: commitment_l1_block)

      batch =
        insert(:arbitrum_l1_batch,
          start_block: start_block,
          end_block: end_block,
          commitment_id: commitment_transaction.id
        )

      blocks =
        Map.new(start_block..end_block, fn block_number ->
          block = insert(:block, number: block_number)
          insert(:arbitrum_batch_block, batch_number: batch.number, block_number: block_number)

          {block_number, block}
        end)

      %{batch: batch, blocks: blocks}
    end

    defp rollup_block_hash(%{blocks: blocks}, block_number) do
      to_string(blocks[block_number].hash)
    end

    # Inserts a lifecycle transaction standing for a confirmation included in the
    # given parent chain block.
    defp insert_confirmation(l1_block_number, timestamp \\ @confirmation_l1_timestamp - 1000) do
      insert(:arbitrum_lifecycle_transaction,
        block_number: l1_block_number,
        timestamp: DateTime.from_unix!(timestamp)
      )
    end

    # Links the given rollup blocks to the given confirmation, as an already
    # processed confirmation would have done.
    defp mark_confirmed(block_numbers, confirmation) do
      Repo.update_all(
        from(rollup_block in BatchBlock, where: rollup_block.block_number in ^Enum.to_list(block_numbers)),
        set: [confirmation_id: confirmation.id]
      )
    end

    defp confirmed_blocks(confirmation) do
      Repo.all(
        from(rollup_block in BatchBlock,
          where: rollup_block.confirmation_id == ^confirmation.id,
          order_by: rollup_block.block_number,
          select: rollup_block.block_number
        )
      )
    end

    defp unconfirmed_blocks do
      Repo.all(
        from(rollup_block in BatchBlock,
          where: is_nil(rollup_block.confirmation_id),
          order_by: rollup_block.block_number,
          select: rollup_block.block_number
        )
      )
    end

    # Inserts an L2-to-L1 message which was sent in the given rollup block and is
    # waiting for a confirmation.
    defp insert_sent_message_from_l2(rollup_block_number) do
      insert(:arbitrum_message,
        direction: :from_l2,
        status: :sent,
        originating_transaction_block_number: rollup_block_number,
        completion_transaction_hash: nil
      )
    end

    defp message_status(message) do
      Repo.get_by!(Message, direction: :from_l2, message_id: message.message_id).status
    end

    # Builds a raw `SendRootUpdated` event log as it arrives from an `eth_getLogs`
    # JSON-RPC response. The hash of the top confirmed rollup block is the third
    # topic; the second topic (the send root) is not used by the discovery.
    defp build_send_root_updated_log(rollup_block_hash, l1_transaction_hash, l1_block_number) do
      %{
        "address" => @outbox_address,
        "blockHash" => "0x" <> String.duplicate("0", 64),
        "blockNumber" => integer_to_quantity(l1_block_number),
        "data" => "0x",
        "logIndex" => "0x0",
        "removed" => false,
        "topics" => [
          @send_root_updated_topic,
          "0x" <> String.duplicate("1", 64),
          rollup_block_hash
        ],
        "transactionHash" => l1_transaction_hash,
        "transactionIndex" => "0x0"
      }
    end

    # Mocks the RPC calls of one discovery run: the `eth_getLogs` request over the
    # discovery range, answered with a single `SendRootUpdated` event confirming
    # `top_block_hash` in the transaction `confirmation_transaction_hash`, and the
    # timestamp of the parent chain block holding that event. `extra_ranges` holds
    # the responses for the parent chain ranges which the batch walk reads
    # afterwards.
    defp expect_discovery(top_block_hash, confirmation_transaction_hash, extra_ranges \\ %{}) do
      expect_discovery_of(
        [build_send_root_updated_log(top_block_hash, confirmation_transaction_hash, @confirmation_l1_block)],
        extra_ranges
      )
    end

    # Mocks the RPC calls of one discovery run which reads several
    # `SendRootUpdated` events. `logs` holds one log per event, in the order in
    # which the parent chain holds the events.
    #
    # A test can also answer a lookup of the batch walk with one of these logs. Such
    # a test builds that log itself and gives it to this function. Thus the
    # description of an event appears once only.
    #
    # `extra_ranges` holds the responses for the parent chain ranges which the
    # batch walk reads afterwards.
    defp expect_discovery_of(logs, extra_ranges \\ %{}) do
      l1_blocks_to_timestamps =
        Map.new(logs, fn log ->
          l1_block_number = quantity_to_integer(log["blockNumber"])

          {l1_block_number, l1_block_timestamp(l1_block_number)}
        end)

      expect_rpc(
        Map.put(extra_ranges, {@discovery_l1_start_block, @discovery_l1_end_block}, logs),
        l1_blocks_to_timestamps
      )
    end

    # The timestamp of a parent chain block which holds a confirmation.
    defp l1_block_timestamp(@lower_confirmation_l1_block), do: @lower_confirmation_l1_timestamp
    defp l1_block_timestamp(@confirmation_l1_block), do: @confirmation_l1_timestamp

    # Mocks both request shapes the discovery issues: the single `eth_getLogs`
    # requests (one per scanned parent chain range) and the batched
    # `eth_getBlockByNumber` request fetching the timestamps of the parent chain
    # blocks holding the confirmations. One closure with two clauses dispatches on
    # the shape of each call, so the two request kinds do not have to be
    # interleaved in the order `expect/4` queues them.
    #
    # The `eth_getLogs` clause also matches the contract and the event signature,
    # so a request for another address or another topic fails the match instead of
    # being answered as if it asked for the `SendRootUpdated` events of the outbox.
    #
    # A parent chain range absent from `get_logs_responses` raises `KeyError`, so
    # an unexpected range fails the test loudly instead of being silently answered
    # with no logs. Every `eth_getLogs` range is also sent to the calling test
    # process - the whole call path runs synchronously in it - to be drained with
    # `drain_get_logs_ranges/0` afterwards.
    defp expect_rpc(get_logs_responses, l1_blocks_to_timestamps) do
      test_pid = self()

      expect(EthereumJSONRPC.Mox, :json_rpc, map_size(get_logs_responses) + 1, fn
        %{
          method: "eth_getLogs",
          params: [
            %{
              fromBlock: from_block_quantity,
              toBlock: to_block_quantity,
              address: @outbox_address,
              topics: [@send_root_updated_topic]
            }
          ]
        },
        _options ->
          from_block = quantity_to_integer(from_block_quantity)
          to_block = quantity_to_integer(to_block_quantity)
          send(test_pid, {:eth_get_logs_range, from_block, to_block})

          {:ok, Map.fetch!(get_logs_responses, {from_block, to_block})}

        requests, _options when is_list(requests) ->
          {block_numbers, responses} =
            requests
            |> Enum.map(fn %{id: id, method: "eth_getBlockByNumber", params: [block_quantity, false]} ->
              block_number = quantity_to_integer(block_quantity)
              timestamp = Map.fetch!(l1_blocks_to_timestamps, block_number)

              {block_number,
               %{
                 id: id,
                 jsonrpc: "2.0",
                 result: %{"number" => block_quantity, "timestamp" => integer_to_quantity(timestamp)}
               }}
            end)
            |> Enum.unzip()

          send(test_pid, {:eth_get_block_numbers, Enum.sort(block_numbers)})

          {:ok, responses}
      end)
    end

    defp drain_get_logs_ranges do
      receive do
        {:eth_get_logs_range, from_block, to_block} -> [{from_block, to_block} | drain_get_logs_ranges()]
      after
        0 -> []
      end
    end

    # Returns one sorted list of parent chain block numbers per batched
    # `eth_getBlockByNumber` request. If the number of the confirmations is less
    # than the chunk size, the discovery asks for the block of each confirmation in
    # one request.
    defp drain_block_number_batches do
      receive do
        {:eth_get_block_numbers, block_numbers} -> [block_numbers | drain_block_number_batches()]
      after
        0 -> []
      end
    end
  end
end
