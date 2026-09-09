# SPDX-License-Identifier: LicenseRef-Blockscout
if Application.get_env(:explorer, :chain_type) == :arbitrum do
  defmodule Indexer.Fetcher.Arbitrum.Workers.Confirmations.Discovery.TwoNewConfirmationsIncompleteDatabaseTest do
    use Indexer.Fetcher.Arbitrum.Workers.Confirmations.Discovery.TestCase

    # See `Indexer.Fetcher.Arbitrum.Workers.Confirmations.Discovery.TestCase` for
    # the conventions this suite of files follows.

    # A parent chain range can hold two new events while the database holds a part of
    # the data which those confirmations need. The indexer writes a batch, the links
    # of its rollup blocks and the blocks themselves in several steps, and the
    # discovery can read the parent chain between those steps.
    #
    # The discovery collects the confirmations of one run from the lowest rollup
    # block to the highest one, and it writes the result of the run in one operation.
    # A confirmation without rollup blocks drops every block which the run collected
    # before it. Thus the order of the two confirmations changes what the run writes,
    # and this group holds both orders of the missing data.
    #
    # Each test of a postponement has two parts. The first part gives the result for
    # the state of the database. The second part makes the change of the indexer, and
    # it examines the same parent chain range again.
    #
    # The last two scenarios of the group hold both events in one parent chain block.
    # There the lookup of a confirmation sees no log of the other confirmation of the
    # same run, thus the missing data and that blind lookup meet in one run. The group
    # "perform/5 with two new confirmations in one parent chain block or in the
    # inverted order" holds the same pairs of events over a complete database.
    describe "perform/5 with two new confirmations and an incomplete database" do
      # Both events are in the same parent chain transaction, and the database holds
      # one batch of the blocks 1..10. No block of the batch is confirmed. The rollup
      # blocks 11..20 are also in the database, but no batch of the database holds
      # them. If the indexer did not handle the batch of those blocks, the database has
      # this state.
      #
      # The lower event points to the rollup block 10. The upper event points to the
      # rollup block 20. Thus the transaction must hold the blocks 1..20 at the end.
      #
      # The discovery finds the number of a rollup block through the batch of that
      # block. The block 20 has no batch. Thus the discovery drops the upper event, and
      # the transaction takes the blocks 1..10.
      #
      # The number of the lifecycle transactions of the range is 1, because the two
      # events are in one transaction. The discovery compares that number with the
      # number of the handled transactions, which is 1 as well. Thus it returns `:ok`,
      # although it dropped one event of the range. The correct result of this run is
      # `:confirmation_missed`, which sends the range to the historical discovery.
      #
      # The second part of the test makes the change of the indexer: the indexer writes
      # the batch of the blocks 11..20. Then the discovery examines the same parent
      # chain range again. The database knows the transaction of the two events now.
      # For such a transaction the discovery examines no rollup block: it assumes that
      # every block of that confirmation is linked already. Thus the blocks 11..20 stay
      # unconfirmed, and no later run can link them.
      #
      # The test "confirms the lower blocks only when the batch of the upper confirmed
      # block is missing" holds the same state of the database with two transactions.
      # There the discovery returns `:confirmation_missed` for the first run, and the
      # second run links the blocks 11..20. This test is the only one which shows that
      # the discovery loses the rollup blocks of an event when another event of the
      # same transaction was handled before.
      #
      # The test holds the correct result of both runs. Thus the first part requires
      # `:confirmation_missed`, and the current run fails that assertion already.
      #
      # The first part holds the result value only. A correction can import the blocks
      # 1..10 of the resolvable event in the first run, as the test with two
      # transactions does, or it can postpone the whole transaction and link the blocks
      # 1..20 in one operation. Both forms are correct, thus the test requires neither
      # of them.
      #
      # The second form needs one more correction: it leaves the batch of the blocks
      # 1..10 unconfirmed for the second run. Then that run handles the two events of
      # the transaction together, and it gives two rows of each block of 1..10. The
      # test "gives all rollup blocks to one confirmation when both events are in the
      # same transaction" holds that defect.
      @tag skip: "Defect: a dropped event of one transaction gives :ok and is never examined again"
      test "gives all rollup blocks to one confirmation when the batch of the upper block arrives later", %{
        json_rpc_named_arguments: json_rpc_named_arguments
      } do
        batch = seed_batch(@rollup_first_block, 10, @commitment_l1_block)
        blocks_without_batch = seed_blocks_without_batch(11, 20)

        confirmation_transaction_hash = to_string(transaction_hash())

        lower_confirmation_log =
          build_send_root_updated_log(
            rollup_block_hash(batch, 10),
            confirmation_transaction_hash,
            @confirmation_l1_block
          )

        upper_confirmation_log =
          build_send_root_updated_log(
            rollup_block_hash(blocks_without_batch, 20),
            confirmation_transaction_hash,
            @confirmation_l1_block,
            log_index: 1
          )

        expect_discovery_of([lower_confirmation_log, upper_confirmation_log])

        assert :confirmation_missed == discover(json_rpc_named_arguments)

        seed_batch_of_blocks(blocks_without_batch, @recent_commitment_l1_block)

        assert :ok == discover(json_rpc_named_arguments)

        # The database holds one confirmation per parent chain transaction. Thus
        # `Repo.get_by!/2` also shows that the two events gave one record.
        confirmation = Repo.get_by!(LifecycleTransaction, hash: confirmation_transaction_hash)
        assert confirmation.block_number == @confirmation_l1_block
        assert DateTime.to_unix(confirmation.timestamp) == @confirmation_l1_timestamp

        assert confirmed_blocks(confirmation) == Enum.to_list(@rollup_first_block..20)
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

      # Both events are new, and both events are in the same parent chain block. The
      # database has one batch of the blocks 1..20, and no block of it is confirmed.
      # The block 20 is in the database, but no row links it to the batch. If the
      # indexer did not handle the whole batch, the database has this state.
      #
      # The lower event points to the rollup block 10. The upper event points to the
      # rollup block 20.
      #
      # The discovery finds the number of a rollup block through the batch of that
      # block. Thus it cannot find the number of the block 20, and it drops the upper
      # event. The lookup range of the lower confirmation holds no log, and the batch
      # starts at the lowest-indexed rollup block. Thus the lower confirmation covers
      # the blocks 1..10, and the import writes it. The return value is
      # `:confirmation_missed`, because the parent chain range holds two events and the
      # import holds one confirmation.
      #
      # The second part of the test makes the change of the indexer: the indexer links
      # the block 20 to its batch. Then the discovery examines the same parent chain
      # range again. The lower confirmation is a known confirmation of that run. The
      # lookup range of the upper confirmation ends one block before the parent chain
      # block of that confirmation, thus it holds no log of the lower confirmation. The
      # discovery takes the block 1 as the start of the range of the upper confirmation,
      # while the database gives the unconfirmed blocks 11..20 only. It reads this
      # difference as an incomplete batch, it writes nothing, and it returns
      # `:confirmation_missed` again. Thus the blocks 11..20 stay unconfirmed, and the
      # historical discovery reads this range again and again.
      #
      # The test "splits one batch between the known lower confirmation and the new
      # upper one of the same parent chain block" of the group "perform/5 with a new
      # confirmation and a known one in one batch" holds the state of the database of
      # the second part with a seeded known confirmation. This test is the only one
      # which shows that the discovery reaches that state itself, and that the indexer
      # alone gives it: no re-org takes part in it.
      @tag skip: "Defect: an upper confirmation of the parent chain block of a known one repeats the range"
      test "postpones the upper confirmation when the batch link of its block arrives later", %{
        json_rpc_named_arguments: json_rpc_named_arguments
      } do
        batch = seed_batch(@rollup_first_block, 20, @commitment_l1_block, unlinked_blocks: [20])

        lower_confirmation_transaction_hash = to_string(transaction_hash())
        upper_confirmation_transaction_hash = to_string(transaction_hash())

        expect_discovery_of([
          build_send_root_updated_log(
            rollup_block_hash(batch, 10),
            lower_confirmation_transaction_hash,
            @confirmation_l1_block
          ),
          build_send_root_updated_log(
            rollup_block_hash(batch, 20),
            upper_confirmation_transaction_hash,
            @confirmation_l1_block,
            log_index: 1,
            transaction_index: 1
          )
        ])

        assert :confirmation_missed == discover(json_rpc_named_arguments)

        lower_confirmation = Repo.get_by!(LifecycleTransaction, hash: lower_confirmation_transaction_hash)
        assert Repo.get_by(LifecycleTransaction, hash: upper_confirmation_transaction_hash) == nil
        assert confirmed_blocks(lower_confirmation) == Enum.to_list(@rollup_first_block..10)

        # `unconfirmed_blocks/0` reads the links of the batches. The block 20 holds no
        # link yet. Thus this assertion does not cover it.
        assert unconfirmed_blocks() == Enum.to_list(11..19)

        link_blocks_to_batch(batch, [20])

        assert :ok == discover(json_rpc_named_arguments)

        upper_confirmation = Repo.get_by!(LifecycleTransaction, hash: upper_confirmation_transaction_hash)
        assert upper_confirmation.block_number == @confirmation_l1_block
        assert confirmed_blocks(upper_confirmation) == Enum.to_list(11..20)
        assert confirmed_blocks(lower_confirmation) == Enum.to_list(@rollup_first_block..10)
        assert unconfirmed_blocks() == []
      end

      # Both events are new, and both events are in the same parent chain block. The
      # database has two batches: the blocks 1..10 and the blocks 11..20. No block is
      # confirmed. The block 5 is not linked to its batch. If the indexer did not
      # handle the whole batch, the database has this state.
      #
      # The lower event points to the rollup block 10. The upper event points to the
      # rollup block 20.
      #
      # The lower confirmation finds the gap between the blocks 4 and 6, thus it gives
      # no rollup block. The upper confirmation must give the blocks 11..20: every
      # block of them is in the database, and the log of the lower confirmation ends
      # the range of the upper one.
      #
      # The lookup range of the upper confirmation ends one block before the parent
      # chain block of that confirmation, thus it holds no log of the lower
      # confirmation. The walk crosses the boundary of the second batch, it meets the
      # same gap in the first batch, and it drops the blocks 11..20 as well. Therefore
      # the run writes nothing, and the first part of the test fails on the upper
      # confirmation.
      #
      # The second part of the test makes the change of the indexer: the indexer links
      # the block 5 to its batch. Then the lower confirmation gives the blocks 1..10,
      # and the walk of the upper confirmation still finds no boundary. Thus it takes
      # the whole first batch, and the blocks 1..10 belong to both confirmations. One
      # import gets two rows of each of those blocks, and the database stops the import
      # with a cardinality violation.
      #
      # The test "writes the upper confirmation only when the lower confirmation finds
      # a gap in its batch" holds the same state of the database with the lower event in
      # an older parent chain block. There the log of the lower confirmation ends the
      # range of the upper one, and the run writes the upper confirmation. This test is
      # the only one where a gap below an invisible boundary drops a confirmation whose
      # own blocks are complete.
      @tag skip: "Defect: two new confirmations in the same parent chain block"
      test "drops the upper confirmation when the lower one of the same parent chain block finds a gap", %{
        json_rpc_named_arguments: json_rpc_named_arguments
      } do
        previous_batch = seed_batch(@rollup_first_block, 10, @previous_commitment_l1_block, unlinked_blocks: [5])
        batch = seed_batch(11, 20, @commitment_l1_block)

        lower_confirmation_transaction_hash = to_string(transaction_hash())
        upper_confirmation_transaction_hash = to_string(transaction_hash())

        expect_discovery_of([
          build_send_root_updated_log(
            rollup_block_hash(previous_batch, 10),
            lower_confirmation_transaction_hash,
            @confirmation_l1_block
          ),
          build_send_root_updated_log(
            rollup_block_hash(batch, 20),
            upper_confirmation_transaction_hash,
            @confirmation_l1_block,
            log_index: 1,
            transaction_index: 1
          )
        ])

        assert :confirmation_missed == discover(json_rpc_named_arguments)

        assert Repo.get_by(LifecycleTransaction, hash: lower_confirmation_transaction_hash) == nil

        upper_confirmation = Repo.get_by!(LifecycleTransaction, hash: upper_confirmation_transaction_hash)
        assert upper_confirmation.block_number == @confirmation_l1_block
        assert confirmed_blocks(upper_confirmation) == Enum.to_list(11..20)
        assert unconfirmed_blocks() == Enum.to_list(@rollup_first_block..4) ++ Enum.to_list(6..10)

        link_blocks_to_batch(previous_batch, [5])

        assert :ok == discover(json_rpc_named_arguments)

        lower_confirmation = Repo.get_by!(LifecycleTransaction, hash: lower_confirmation_transaction_hash)
        assert confirmed_blocks(lower_confirmation) == Enum.to_list(@rollup_first_block..10)
        assert confirmed_blocks(upper_confirmation) == Enum.to_list(11..20)
        assert unconfirmed_blocks() == []
      end
    end
  end
end
