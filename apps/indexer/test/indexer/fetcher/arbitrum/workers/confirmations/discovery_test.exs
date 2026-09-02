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

    # Bound at compile time so that the `eth_getLogs` clause of the mock can match
    # it: a pattern cannot call a function.
    @send_root_updated_topic ArbitrumEvents.send_root_updated()

    # One call of `perform/5` reads the logs of this parent chain range. The
    # `SendRootUpdated` event of each test is in the parent chain block 200.
    @discovery_l1_start_block 195
    @discovery_l1_end_block 205
    @confirmation_l1_block 200
    @confirmation_l1_timestamp 1_700_000_000

    # One parent chain range can hold two `SendRootUpdated` events. The lower
    # confirmation confirms the lower rollup blocks. The parent chain usually holds
    # it in an older block than the upper confirmation, and this block is that older
    # block. Two tests hold both events in `@confirmation_l1_block` instead, because
    # one parent chain block can hold two confirmations. The upper confirmation is
    # the confirmation which every test of a single event uses.
    @lower_confirmation_l1_block 198
    @lower_confirmation_l1_timestamp @confirmation_l1_timestamp - 24

    # One parent chain range can also hold three `SendRootUpdated` events. The
    # confirmation of the lowest rollup blocks is in the oldest block of the three.
    @lowest_confirmation_l1_block 196
    @lowest_confirmation_l1_timestamp @confirmation_l1_timestamp - 48

    # This is the parent chain block which the database holds for a confirmation
    # that a re-org moved. This block is less than the parent chain block of each
    # event. Thus the discovery always finds a difference and writes such a
    # transaction again.
    @stale_confirmation_l1_block 190

    # Wide enough to keep every parent chain lookup of the batch walk within one
    # `eth_getLogs` request. One test passes a short range instead, to make the
    # discovery read a lookup in several chunks.
    @logs_block_range 1000

    # With this range the discovery splits the wider lookups of a batch walk into
    # several chunks. It also keeps two confirmations of one run in two different
    # chunks.
    @short_logs_block_range 3

    # The parent chain block of a confirmation which happened before the one under
    # discovery. This block is between the commitments of the batches and the
    # confirmation under discovery, thus the discovery can find that earlier
    # confirmation. The test of the re-link also puts a stale link to this block.
    # That link belongs to a transaction which the parent chain does not hold.
    @earlier_confirmation_l1_block 150

    # The parent chain blocks of the commitment transactions of the batches. The
    # first one belongs to the batch with the confirmed block. The other ones
    # belong to the batches below it.
    @commitment_l1_block 100
    @previous_commitment_l1_block 90
    @oldest_commitment_l1_block 80

    # The parent chain block of a commitment transaction which is close to the
    # confirmations. A batch with such a commitment has a short lookup range.
    @recent_commitment_l1_block 194

    # The lowest-indexed rollup block. The oldest batch of each test starts here.
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
    #   - one set of `SendRootUpdated` events which the parent chain holds
    #   - the result which the discovery must produce
    #
    # A test gives one log per event. The mock answers each `eth_getLogs` request
    # with the logs of the requested range. Thus a test holds neither the ranges
    # which the discovery reads nor the number of the requests.
    # Those values show how the discovery collects the data, and a change of them
    # keeps a scenario correct. A test of the number of the requests belongs to
    # `Events.get_logs_for_confirmations/5` and to
    # `RollupBlocks.extend_confirmations/3`, which are the functions that make the
    # requests.
    #
    # The `describe` blocks group the scenarios by the set of events:
    #   - one new confirmation
    #   - one confirmation which the database knows already
    #   - two new confirmations
    #   - a new confirmation together with a known one
    #   - two known confirmations
    #   - three new confirmations
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
    #
    # Some scenarios show a defect of the discovery. The test of such a scenario holds
    # the correct result. It carries the tag `@tag skip: "Defect: ..."`, which names
    # the defect. The output of the run shows the test as skipped, but it does not
    # show this name. Thus the tag keeps the name of the defect in one place, and a
    # search for the word "Defect" gives every test of this kind. The correction of
    # the defect removes the tag.

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
      # The caller repeats the same parent chain range after such a result. When the
      # indexer links the other blocks to the batch, the discovery writes the
      # confirmation.
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
      # The caller repeats the same parent chain range after such a result. When the
      # indexer links the block 5 to the batch, the discovery writes the
      # confirmation.
      test "postpones the confirmation when the blocks of the batch hold a gap", %{
        json_rpc_named_arguments: json_rpc_named_arguments
      } do
        batch = seed_batch(@rollup_first_block, 10, @commitment_l1_block, unlinked_blocks: [5])

        confirmation_transaction_hash = to_string(transaction_hash())

        expect_discovery(rollup_block_hash(batch, 10), confirmation_transaction_hash)

        assert :confirmation_missed == discover(json_rpc_named_arguments)

        assert Repo.get_by(LifecycleTransaction, hash: confirmation_transaction_hash) == nil

        assert unconfirmed_blocks() == Enum.to_list(@rollup_first_block..4) ++ Enum.to_list(6..10)
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
      # The caller repeats the same parent chain range after such a result. When the
      # batch below is in the database, the discovery writes the confirmation.
      test "postpones the confirmation when the batch below the current one is missing", %{
        json_rpc_named_arguments: json_rpc_named_arguments
      } do
        batch = seed_batch(11, 20, @commitment_l1_block)

        confirmation_transaction_hash = to_string(transaction_hash())

        expect_discovery(rollup_block_hash(batch, 20), confirmation_transaction_hash)

        assert :confirmation_missed == discover(json_rpc_named_arguments)

        assert Repo.get_by(LifecycleTransaction, hash: confirmation_transaction_hash) == nil

        assert unconfirmed_blocks() == Enum.to_list(11..20)
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
      # The test "postpones both confirmations when the batch of the lower confirmed
      # block is missing" holds the same state of the database. In that test the two
      # events are in the discovery range. When the earlier event is outside the
      # discovery range, the result stays the same.
      #
      # The caller repeats the same parent chain range after such a result. When the
      # batch of the block 10 is in the database, the discovery writes the
      # confirmation.
      test "postpones the confirmation when an earlier event points to a block without a batch", %{
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
      end

      # The database has two batches: the blocks 1..10 and the blocks 11..20. No
      # block is confirmed.
      #
      # The parent chain holds two events. The older event points to the rollup block
      # 20, and it is outside the discovery range. The newer event points to the
      # rollup block 10, and it is in the discovery range. Thus the newer transaction
      # confirms the lower rollup blocks.
      #
      # The two blocks are in two different batches. The lookup of the newer
      # confirmation examines the batch of the block 10 only. The log of the older
      # event points to a block above that batch. Thus the lookup does not use that
      # log, and the newer confirmation covers the blocks 1..10.
      #
      # The blocks 11..20 stay unconfirmed. Those blocks belong to the older
      # confirmation. A later run of the historical discovery reaches the older event,
      # and it links those blocks to that event.
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
      # The parent chain holds two events. The older event points to the rollup block
      # 10, and it is outside the discovery range. The newer event points to the
      # rollup block 5, and it is in the discovery range. Thus the newer transaction
      # confirms the lower rollup blocks. The HPP mainnet, which is an Arbitrum
      # AnyTrust chain, holds such a pair of confirmations.
      #
      # The newer event confirms the blocks 1..5. Thus the discovery must write that
      # confirmation with the blocks 1..5, and it must return `:ok`. The blocks 6..10
      # belong to the older confirmation. A later run of the historical discovery
      # reaches the older event, and it links those blocks to that event.
      #
      # The discovery finds the log of the older event in the lookup range of the
      # newer event. That log points to the block 10. Thus the discovery takes the
      # block 11 as the first unconfirmed block of the batch. The block 11 is above
      # the block 5. Therefore the discovery finds no block for the confirmation, and
      # it writes nothing. The return value is `:confirmation_missed`.
      #
      # The historical discovery keeps the same parent chain range after such a
      # result. No change of the database can give another result for this range.
      # Thus the historical discovery reads this range again and again.
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

        assert :ok == discover(json_rpc_named_arguments)

        confirmation = Repo.get_by!(LifecycleTransaction, hash: confirmation_transaction_hash)
        assert confirmation.block_number == @confirmation_l1_block
        assert DateTime.to_unix(confirmation.timestamp) == @confirmation_l1_timestamp

        assert confirmed_blocks(confirmation) == Enum.to_list(@rollup_first_block..5)
        assert unconfirmed_blocks() == Enum.to_list(6..10)
      end
    end

    # The parent chain transaction of the event is in the database already, as a
    # lifecycle transaction. Thus the rollup blocks of this confirmation are linked
    # to it already.
    #
    # In this condition the discovery does not examine the rollup blocks one more
    # time. It only compares the block number and the timestamp of the known
    # transaction with the values from the event. A difference between them
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

        updated_confirmation = Repo.get_by!(LifecycleTransaction, hash: existing_confirmation.hash)
        assert updated_confirmation.id == existing_confirmation.id
        assert updated_confirmation.block_number == @confirmation_l1_block
        assert DateTime.to_unix(updated_confirmation.timestamp) == @confirmation_l1_timestamp
        assert updated_confirmation.status == existing_confirmation.status

        assert unconfirmed_blocks() == Enum.to_list(@rollup_first_block..10)
      end

      # The lifecycle transaction of the confirmation is in the database. Its block
      # number and its timestamp are equal to the values in the event.
      #
      # The discovery finds no difference, thus it writes nothing and the result is
      # `:ok`. This is the usual result when the discovery reads the same parent
      # chain range one more time.
      test "leaves the confirmation transaction untouched when nothing changed", %{
        json_rpc_named_arguments: json_rpc_named_arguments
      } do
        existing_confirmation = insert_confirmation(@confirmation_l1_block, @confirmation_l1_timestamp)

        expect_discovery(to_string(block_hash()), to_string(existing_confirmation.hash))

        assert :ok == discover(json_rpc_named_arguments)

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
      # The caller repeats the same parent chain range after such a result. The lower
      # confirmation is a known confirmation in that run. The lookup range of the
      # upper confirmation holds the log of the lower confirmation. Thus the upper
      # confirmation covers the blocks 11..20, and the import of the lower
      # confirmation alone gives no hole in the confirmation history.
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
      # The caller repeats the same parent chain range after such a result. When the
      # batch of the block 10 is in the database, the two confirmations arrive
      # together.
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
      # The caller repeats the same parent chain range after such a result. When the
      # indexer links the block 15 to its batch, the two confirmations arrive
      # together.
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
      # The caller repeats the same parent chain range after such a result. The upper
      # confirmation is a known confirmation in that run.
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
      end
    end

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
    end

    # The database can know both confirmations of the range already. Then the
    # discovery examines no rollup block, and it reads no more logs. It compares
    # the block number and the timestamp of each known transaction with the values
    # of its event. It writes only the transactions which show a
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

      # Both confirmations of the range are in the database, and both events are in
      # the same parent chain block. One block of the parent chain can hold two calls
      # which confirm a node. Then the parent chain gives this state.
      #
      # The values of both confirmations are equal to the values of their events. Thus
      # the discovery writes nothing, and the result is `:ok`.
      #
      # This test is not redundant. It is the only test of this group which puts two
      # events into one parent chain block. One parent chain block can hold two
      # transactions which confirm a node.
      #
      # As in the test before, the events point to block hashes outside the database,
      # and the test seeds no batch. Thus the count of the rows is exact.
      #
      # The two hashes are different, because each event confirms another node. The
      # discovery reads neither of them. It takes the hash of a rollup block only for a
      # confirmation which the database does not know.
      test "keeps both known confirmations when the two events are in one parent chain block", %{
        json_rpc_named_arguments: json_rpc_named_arguments
      } do
        first_confirmation = insert_confirmation(@confirmation_l1_block, @confirmation_l1_timestamp)
        second_confirmation = insert_confirmation(@confirmation_l1_block, @confirmation_l1_timestamp)

        expect_discovery_of([
          build_send_root_updated_log(
            to_string(block_hash()),
            to_string(first_confirmation.hash),
            @confirmation_l1_block
          ),
          build_send_root_updated_log(
            to_string(block_hash()),
            to_string(second_confirmation.hash),
            @confirmation_l1_block,
            log_index: 1,
            transaction_index: 1
          )
        ])

        assert :ok == discover(json_rpc_named_arguments)

        # This test seeds no batch. Thus the database holds the two confirmations
        # only.
        assert Repo.aggregate(LifecycleTransaction, :count) == 2

        kept_first_confirmation = Repo.get_by!(LifecycleTransaction, hash: first_confirmation.hash)
        assert kept_first_confirmation.id == first_confirmation.id
        assert kept_first_confirmation.block_number == @confirmation_l1_block
        assert DateTime.compare(kept_first_confirmation.timestamp, first_confirmation.timestamp) == :eq

        kept_second_confirmation = Repo.get_by!(LifecycleTransaction, hash: second_confirmation.hash)
        assert kept_second_confirmation.id == second_confirmation.id
        assert kept_second_confirmation.block_number == @confirmation_l1_block
        assert DateTime.compare(kept_second_confirmation.timestamp, second_confirmation.timestamp) == :eq
      end
    end

    # A parent chain range can hold three `SendRootUpdated` events. Then two
    # confirmations are earlier than the last one, and the lookup range of the last
    # confirmation holds both of them.
    #
    # A lookup range holds two earlier confirmations in other conditions as well. The
    # parent chain can already hold two confirmations of the same batch below the
    # discovery range. Then one new event is enough. Only this group holds three new
    # confirmations of one run, split over one batch.
    #
    # The discovery must take the newest of the two earlier confirmations. It reads a
    # lookup range in chunks, from the newest chunk to the oldest chunk. It stops at
    # the first chunk which holds a confirmation of the batch. Within one chunk it
    # takes the confirmation with the highest rollup block.
    #
    # The tests of this group give a name to each of the three confirmations. The
    # names are the lowest confirmation, the lower confirmation and the upper
    # confirmation, in the order of their rollup blocks.
    describe "perform/5 with three new confirmations" do
      # The database has one batch with the rollup blocks 1..20. No block of it is
      # confirmed.
      #
      # The three events point to the rollup blocks 5, 10 and 20. All three blocks
      # are in the same batch. The maximum range of one `eth_getLogs` request is wider
      # than each lookup range. Thus the discovery reads each lookup range in one
      # chunk.
      #
      # The lookup range of the upper confirmation holds two confirmations of the
      # batch. They point to the rollup blocks 5 and 10. The discovery must take the
      # block 10, because it is the higher block. As a result, the upper confirmation
      # covers the blocks 11..20.
      #
      # This test is the only test which puts two confirmations of one batch into one
      # chunk. If the discovery takes the block 5, the upper confirmation covers the
      # blocks 6..20. Then the upper confirmation takes the blocks of the lower
      # confirmation again, and the database operation fails.
      #
      # The lookup response of the upper confirmation intentionally puts the newer
      # confirmation first. An `eth_getLogs` response usually puts the older
      # confirmation first.
      #
      # `fetch_and_sort_confirmations_logs/4` adds each block number to the front of
      # its list. It puts the lower block number first. Thus `Enum.sort/2` must put
      # the higher block number first again.
      test "takes the higher of the two earlier confirmations which are in one chunk", %{
        json_rpc_named_arguments: json_rpc_named_arguments
      } do
        batch = seed_batch(@rollup_first_block, 20, @commitment_l1_block)

        lowest_confirmation_transaction_hash = to_string(transaction_hash())
        lower_confirmation_transaction_hash = to_string(transaction_hash())
        upper_confirmation_transaction_hash = to_string(transaction_hash())

        lowest_confirmation_log =
          build_send_root_updated_log(
            rollup_block_hash(batch, 5),
            lowest_confirmation_transaction_hash,
            @lowest_confirmation_l1_block
          )

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

        # The mock keeps this order in every response. Thus a response which holds
        # the two earlier confirmations puts the newer one first.
        expect_discovery_of([lower_confirmation_log, lowest_confirmation_log, upper_confirmation_log])

        assert :ok == discover(json_rpc_named_arguments)

        lowest_confirmation = Repo.get_by!(LifecycleTransaction, hash: lowest_confirmation_transaction_hash)
        lower_confirmation = Repo.get_by!(LifecycleTransaction, hash: lower_confirmation_transaction_hash)
        upper_confirmation = Repo.get_by!(LifecycleTransaction, hash: upper_confirmation_transaction_hash)

        assert lowest_confirmation.block_number == @lowest_confirmation_l1_block
        assert DateTime.to_unix(lowest_confirmation.timestamp) == @lowest_confirmation_l1_timestamp

        assert confirmed_blocks(lowest_confirmation) == Enum.to_list(@rollup_first_block..5)
        assert confirmed_blocks(lower_confirmation) == Enum.to_list(6..10)
        assert confirmed_blocks(upper_confirmation) == Enum.to_list(11..20)
        assert unconfirmed_blocks() == []
      end

      # The database has one batch with the rollup blocks 1..20, and no block of it
      # is confirmed. The parent chain holds the commitment of the batch in the block
      # 194, which is close to the three confirmations.
      #
      # The three events point to the rollup blocks 5, 10 and 20. The test before uses
      # the same three blocks. But in this test the maximum range of one `eth_getLogs`
      # request is three blocks. Thus the discovery reads a lookup range in several
      # chunks.
      #
      # The lookup range of the upper confirmation is 194..199. The newest chunk of
      # this range is 197..199, and this chunk holds the confirmation of the block
      # 10. Thus the discovery stops at this chunk. It does not read the chunk
      # 194..196, which holds the confirmation of the block 5.
      #
      # The list of the requested ranges shows this result. The discovery reads one
      # chunk for each of the three confirmations.
      test "stops at the newest chunk which holds an earlier confirmation", %{
        json_rpc_named_arguments: json_rpc_named_arguments
      } do
        batch = seed_batch(@rollup_first_block, 20, @recent_commitment_l1_block)

        lowest_confirmation_transaction_hash = to_string(transaction_hash())
        lower_confirmation_transaction_hash = to_string(transaction_hash())
        upper_confirmation_transaction_hash = to_string(transaction_hash())

        lowest_confirmation_log =
          build_send_root_updated_log(
            rollup_block_hash(batch, 5),
            lowest_confirmation_transaction_hash,
            @lowest_confirmation_l1_block
          )

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

        expect_discovery_of([lowest_confirmation_log, lower_confirmation_log, upper_confirmation_log])

        assert :ok == discover(json_rpc_named_arguments, @short_logs_block_range)

        lowest_confirmation = Repo.get_by!(LifecycleTransaction, hash: lowest_confirmation_transaction_hash)
        lower_confirmation = Repo.get_by!(LifecycleTransaction, hash: lower_confirmation_transaction_hash)
        upper_confirmation = Repo.get_by!(LifecycleTransaction, hash: upper_confirmation_transaction_hash)

        assert confirmed_blocks(lowest_confirmation) == Enum.to_list(@rollup_first_block..5)
        assert confirmed_blocks(lower_confirmation) == Enum.to_list(6..10)
        assert confirmed_blocks(upper_confirmation) == Enum.to_list(11..20)
        assert unconfirmed_blocks() == []
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

    # Inserts a batch with its commitment transaction and the rollup blocks of that
    # batch. No block of the batch is confirmed (`confirmation_id` is `nil`).
    # Returns the batch together with the blocks, keyed by block number.
    #
    # `unlinked_blocks` names the blocks which stay outside the batch. Such a block
    # is in the database, but no row links it to the batch. If the indexer did not
    # handle the whole batch, the database has this state. The discovery does not
    # find such a block through the batch of that block.
    #
    # Note: `arbitrum_l1_batch_factory` inserts a lifecycle transaction of its own
    # before it applies the `commitment_id` override. Thus each call leaves one
    # unused lifecycle transaction in the database. A count of the rows of
    # `LifecycleTransaction` is therefore not a usable assertion in a test which
    # seeds a batch. Find the transaction by its hash instead.
    defp seed_batch(start_block, end_block, commitment_l1_block, options \\ []) do
      commitment_transaction = insert(:arbitrum_lifecycle_transaction, block_number: commitment_l1_block)

      batch =
        insert(:arbitrum_l1_batch,
          start_block: start_block,
          end_block: end_block,
          commitment_id: commitment_transaction.id
        )

      unlinked_blocks = Keyword.get(options, :unlinked_blocks, [])

      blocks =
        Map.new(start_block..end_block, fn block_number ->
          block = insert(:block, number: block_number)

          if block_number not in unlinked_blocks do
            insert(:arbitrum_batch_block, batch_number: batch.number, block_number: block_number)
          end

          {block_number, block}
        end)

      %{batch: batch, blocks: blocks}
    end

    # Inserts rollup blocks which no batch of the database holds. If the indexer did
    # not handle the batch of those blocks, the database has this state. Returns the
    # blocks in the shape which `seed_batch/4` returns.
    defp seed_blocks_without_batch(start_block, end_block) do
      blocks =
        Map.new(start_block..end_block, fn block_number ->
          {block_number, insert(:block, number: block_number)}
        end)

      %{blocks: blocks}
    end

    defp rollup_block_hash(%{blocks: blocks}, block_number) do
      to_string(blocks[block_number].hash)
    end

    # Inserts a lifecycle transaction which stands for a confirmation in the given
    # parent chain block.
    defp insert_confirmation(l1_block_number, timestamp \\ @confirmation_l1_timestamp - 1000) do
      insert(:arbitrum_lifecycle_transaction,
        block_number: l1_block_number,
        timestamp: DateTime.from_unix!(timestamp)
      )
    end

    # Links the given rollup blocks to the given confirmation. An earlier run of the
    # discovery makes the same links.
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

    # Returns the rollup blocks which hold a link to a batch and no link to a
    # confirmation. A rollup block without a batch is not in this list.
    defp unconfirmed_blocks do
      Repo.all(
        from(rollup_block in BatchBlock,
          where: is_nil(rollup_block.confirmation_id),
          order_by: rollup_block.block_number,
          select: rollup_block.block_number
        )
      )
    end

    # Inserts an L2-to-L1 message which was sent in the given rollup block and which
    # waits for a confirmation.
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

    # Builds a raw `SendRootUpdated` event log, in the shape of an `eth_getLogs`
    # JSON-RPC response. The hash of the top confirmed rollup block is the third
    # topic. The discovery does not use the second topic, which is the send root.
    # `options` gives a different position to each log of one parent chain block.
    defp build_send_root_updated_log(rollup_block_hash, l1_transaction_hash, l1_block_number, options \\ []) do
      %{
        "address" => @outbox_address,
        "blockHash" => "0x" <> String.duplicate("0", 64),
        "blockNumber" => integer_to_quantity(l1_block_number),
        "data" => "0x",
        "logIndex" => integer_to_quantity(Keyword.get(options, :log_index, 0)),
        "removed" => false,
        "topics" => [
          @send_root_updated_topic,
          "0x" <> String.duplicate("1", 64),
          rollup_block_hash
        ],
        "transactionHash" => l1_transaction_hash,
        "transactionIndex" => integer_to_quantity(Keyword.get(options, :transaction_index, 0))
      }
    end

    # Mocks the RPC calls of one discovery run whose parent chain holds a single
    # `SendRootUpdated` event. The event confirms `top_block_hash` in the
    # transaction `confirmation_transaction_hash`.
    defp expect_discovery(top_block_hash, confirmation_transaction_hash) do
      expect_discovery_of([
        build_send_root_updated_log(top_block_hash, confirmation_transaction_hash, @confirmation_l1_block)
      ])
    end

    # Mocks the RPC calls of one discovery run. `logs` holds every
    # `SendRootUpdated` log which the parent chain has, and not only the logs of
    # the discovery range. The mock answers each `eth_getLogs` request with the
    # logs of the requested range. Thus a test gives the state of the parent chain,
    # and it gives no range of its own.
    #
    # The order of `logs` is the order of each response. A test which needs a
    # certain order gives that order here.
    defp expect_discovery_of(logs) do
      l1_blocks_to_timestamps =
        logs
        |> logs_of_range(@discovery_l1_start_block, @discovery_l1_end_block)
        |> Map.new(fn log ->
          l1_block_number = quantity_to_integer(log["blockNumber"])

          {l1_block_number, l1_block_timestamp(l1_block_number)}
        end)

      expect_rpc(logs, l1_blocks_to_timestamps)
    end

    # The logs of one parent chain range. Both ends of the range belong to it.
    defp logs_of_range(logs, from_block, to_block) do
      Enum.filter(logs, fn log ->
        l1_block_number = quantity_to_integer(log["blockNumber"])

        l1_block_number >= from_block and l1_block_number <= to_block
      end)
    end

    # The timestamp of a parent chain block which holds a confirmation.
    defp l1_block_timestamp(@lowest_confirmation_l1_block), do: @lowest_confirmation_l1_timestamp
    defp l1_block_timestamp(@lower_confirmation_l1_block), do: @lower_confirmation_l1_timestamp
    defp l1_block_timestamp(@confirmation_l1_block), do: @confirmation_l1_timestamp

    # Mocks the two request shapes which the discovery makes:
    #   - one `eth_getLogs` request per parent chain range
    #   - one batched `eth_getBlockByNumber` request for the timestamps of the
    #     parent chain blocks which hold the confirmations
    #
    # One closure with two clauses dispatches on the shape of each call.
    #
    # The `eth_getLogs` clause also matches the contract and the event signature.
    # Thus a request for another address or another topic fails the match. The mock
    # does not answer it as a request for the `SendRootUpdated` events of the
    # outbox.
    #
    # The `eth_getLogs` clause answers with the logs of the requested range. Thus a
    # change of the ranges of the walk does not fail the mock. The state of the
    # database stays the only subject of a test.
    defp expect_rpc(parent_chain_logs, l1_blocks_to_timestamps) do
      stub(EthereumJSONRPC.Mox, :json_rpc, fn
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

          {:ok, logs_of_range(parent_chain_logs, from_block, to_block)}

        requests, _options when is_list(requests) ->
          responses =
            Enum.map(requests, fn %{id: id, method: "eth_getBlockByNumber", params: [block_quantity, false]} ->
              block_number = quantity_to_integer(block_quantity)
              timestamp = Map.fetch!(l1_blocks_to_timestamps, block_number)

              %{
                id: id,
                jsonrpc: "2.0",
                result: %{"number" => block_quantity, "timestamp" => integer_to_quantity(timestamp)}
              }
            end)

          {:ok, responses}
      end)
    end
  end
end
