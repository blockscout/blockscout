# SPDX-License-Identifier: LicenseRef-Blockscout
if Application.get_env(:explorer, :chain_type) == :arbitrum do
  defmodule Indexer.Fetcher.Arbitrum.Workers.Confirmations.OneWindowTest do
    use Indexer.Fetcher.Arbitrum.Workers.Confirmations.TestCase

    # See `Indexer.Fetcher.Arbitrum.Workers.Confirmations.TestCase` for the
    # conventions this suite of files follows.

    # A `SendRootUpdated` event on the parent chain confirms one rollup block. The
    # event also confirms all rollup blocks below that block. The discovery writes
    # one row with the confirmed block `top` for each event. The order of `top`
    # gives the owner of each rollup block: the row with the lowest `top` which is
    # not below the block.
    #
    # Each test of this group gives the main process one window with a set of
    # events, and it examines the rows and the owners after the window. The
    # position of an event in the parent chain does not change the result. Thus
    # the tests of two events hold the events in one parent chain block, in the
    # normal order, and in the inverted order.
    #
    # No test of this group seeds a batch. The discovery reads the number of a
    # confirmed rollup block from the indexed blocks, and it does not read the
    # batches. Thus each test also holds the case of an indexed rollup block
    # without a link to a batch.
    describe "check_new/1 with the events of one window" do
      # The database has the rollup blocks 1..12 and no confirmation. The event
      # points to the rollup block 10.
      #
      # The row owns the blocks from 0, also the block 0 which the instance does
      # not index. The discovery also changes the status of the L2-to-L1
      # messages. A message sent in the block 10 or below becomes `:confirmed`. A
      # message from a higher block keeps the status `:sent`.
      test "confirms every rollup block up to the confirmed block and the L2-to-L1 messages", %{
        json_rpc_named_arguments: json_rpc_named_arguments
      } do
        blocks = seed_blocks(1..12)
        seed_cursors()

        confirmation_transaction_hash = to_string(transaction_hash())
        confirmed_message = insert_sent_message_from_l2(9)
        # The top confirmed block belongs to the confirmation too. Thus a
        # message sent in that block must also change its status.
        boundary_message = insert_sent_message_from_l2(10)
        not_yet_confirmed_message = insert_sent_message_from_l2(11)

        expect_parent_chain([
          build_send_root_updated_log(
            rollup_block_hash(blocks, 10),
            confirmation_transaction_hash,
            @confirmation_l1_block
          )
        ])

        run_main(state(json_rpc_named_arguments))

        assert rows() == [{10, confirmation_transaction_hash}]

        assert owners(0..12) ==
                 Map.merge(owned_by(0..10, confirmation_transaction_hash), owned_by(11..12, nil))

        confirmation_transaction = lifecycle_transaction(confirmation_transaction_hash)
        assert confirmation_transaction.block_number == @confirmation_l1_block
        assert DateTime.to_unix(confirmation_transaction.timestamp) == @confirmation_l1_timestamp
        assert confirmation_transaction.status == :unfinalized

        assert message_status(confirmed_message) == :confirmed
        assert message_status(boundary_message) == :confirmed
        assert message_status(not_yet_confirmed_message) == :sent
      end

      # The database knows the parent chain transaction of the event already, but
      # the table of confirmations has no row for it. This is the state after the
      # switch to the table of confirmations.
      #
      # The discovery writes the row. A re-org moved the transaction: the database
      # holds an older parent chain block for it. The discovery updates the block
      # number and the timestamp of the transaction, and it keeps the status
      # `:finalized`.
      test "writes the row of a known confirmation transaction and updates its position", %{
        json_rpc_named_arguments: json_rpc_named_arguments
      } do
        blocks = seed_blocks(1..12)
        seed_cursors()

        known_confirmation = insert_confirmation(@stale_confirmation_l1_block)
        known_confirmation_hash = to_string(known_confirmation.hash)

        expect_parent_chain([
          build_send_root_updated_log(rollup_block_hash(blocks, 10), known_confirmation_hash, @confirmation_l1_block)
        ])

        run_main(state(json_rpc_named_arguments))

        assert rows() == [{10, known_confirmation_hash}]
        assert owners(0..12) == Map.merge(owned_by(0..10, known_confirmation_hash), owned_by(11..12, nil))

        updated_confirmation = lifecycle_transaction(known_confirmation_hash)
        assert updated_confirmation.id == known_confirmation.id
        assert updated_confirmation.block_number == @confirmation_l1_block
        assert DateTime.to_unix(updated_confirmation.timestamp) == @confirmation_l1_timestamp
        assert updated_confirmation.status == :finalized
      end

      # Two events in the normal order: the lower confirmation is in an older
      # parent chain block. The lower row owns the blocks up to its `top`, and the
      # upper row owns the blocks above it.
      test "splits the rollup blocks between two confirmations in the normal order", %{
        json_rpc_named_arguments: json_rpc_named_arguments
      } do
        blocks = seed_blocks(1..22)
        seed_cursors()

        lower_hash = to_string(transaction_hash())
        upper_hash = to_string(transaction_hash())

        expect_parent_chain([
          build_send_root_updated_log(rollup_block_hash(blocks, 10), lower_hash, @lower_confirmation_l1_block),
          build_send_root_updated_log(rollup_block_hash(blocks, 20), upper_hash, @confirmation_l1_block)
        ])

        run_main(state(json_rpc_named_arguments))

        assert rows() == [{10, lower_hash}, {20, upper_hash}]

        assert owners(0..22) ==
                 owned_by(0..10, lower_hash)
                 |> Map.merge(owned_by(11..20, upper_hash))
                 |> Map.merge(owned_by(21..22, nil))
      end

      # Two events in one parent chain block. The result is the same as in the
      # normal order.
      test "splits the rollup blocks between two confirmations of one parent chain block", %{
        json_rpc_named_arguments: json_rpc_named_arguments
      } do
        blocks = seed_blocks(1..22)
        seed_cursors()

        lower_hash = to_string(transaction_hash())
        upper_hash = to_string(transaction_hash())

        expect_parent_chain([
          build_send_root_updated_log(rollup_block_hash(blocks, 10), lower_hash, @confirmation_l1_block,
            transaction_index: 0
          ),
          build_send_root_updated_log(rollup_block_hash(blocks, 20), upper_hash, @confirmation_l1_block,
            transaction_index: 1
          )
        ])

        run_main(state(json_rpc_named_arguments))

        assert rows() == [{10, lower_hash}, {20, upper_hash}]

        assert owners(0..22) ==
                 owned_by(0..10, lower_hash)
                 |> Map.merge(owned_by(11..20, upper_hash))
                 |> Map.merge(owned_by(21..22, nil))
      end

      # Two events in the inverted order: the older parent chain block holds the
      # confirmation of the higher rollup block. An AnyTrust chain gives this
      # order. The result is the same as in the normal order, because the owner
      # follows only the order of `top`.
      test "splits the rollup blocks between two confirmations in the inverted order", %{
        json_rpc_named_arguments: json_rpc_named_arguments
      } do
        blocks = seed_blocks(1..22)
        seed_cursors()

        lower_hash = to_string(transaction_hash())
        upper_hash = to_string(transaction_hash())

        expect_parent_chain([
          build_send_root_updated_log(rollup_block_hash(blocks, 20), upper_hash, @lower_confirmation_l1_block),
          build_send_root_updated_log(rollup_block_hash(blocks, 10), lower_hash, @confirmation_l1_block)
        ])

        run_main(state(json_rpc_named_arguments))

        assert rows() == [{10, lower_hash}, {20, upper_hash}]

        assert owners(0..22) ==
                 owned_by(0..10, lower_hash)
                 |> Map.merge(owned_by(11..20, upper_hash))
                 |> Map.merge(owned_by(21..22, nil))
      end

      # One parent chain transaction emits two events. Each event gets its own row,
      # and both rows refer to one lifecycle transaction.
      test "writes two rows for two events of one parent chain transaction", %{
        json_rpc_named_arguments: json_rpc_named_arguments
      } do
        blocks = seed_blocks(1..22)
        seed_cursors()

        confirmation_transaction_hash = to_string(transaction_hash())

        expect_parent_chain([
          build_send_root_updated_log(
            rollup_block_hash(blocks, 10),
            confirmation_transaction_hash,
            @confirmation_l1_block,
            log_index: 0
          ),
          build_send_root_updated_log(
            rollup_block_hash(blocks, 20),
            confirmation_transaction_hash,
            @confirmation_l1_block,
            log_index: 1
          )
        ])

        run_main(state(json_rpc_named_arguments))

        assert rows() == [{10, confirmation_transaction_hash}, {20, confirmation_transaction_hash}]
        assert owners(0..22) == Map.merge(owned_by(0..20, confirmation_transaction_hash), owned_by(21..22, nil))
        assert Repo.aggregate(LifecycleTransaction, :count) == 1
      end

      # Three events, and the RPC node gives the logs in a different order than
      # the order of the parent chain blocks. The result does not depend on the
      # order of the logs.
      test "does not depend on the order of the logs in the response", %{
        json_rpc_named_arguments: json_rpc_named_arguments
      } do
        blocks = seed_blocks(1..32)
        seed_cursors()

        lowest_hash = to_string(transaction_hash())
        middle_hash = to_string(transaction_hash())
        highest_hash = to_string(transaction_hash())

        expect_parent_chain([
          build_send_root_updated_log(rollup_block_hash(blocks, 30), highest_hash, @confirmation_l1_block),
          build_send_root_updated_log(rollup_block_hash(blocks, 10), lowest_hash, @lowest_confirmation_l1_block),
          build_send_root_updated_log(rollup_block_hash(blocks, 20), middle_hash, @lower_confirmation_l1_block)
        ])

        run_main(state(json_rpc_named_arguments))

        assert rows() == [{10, lowest_hash}, {20, middle_hash}, {30, highest_hash}]

        assert owners(0..32) ==
                 owned_by(0..10, lowest_hash)
                 |> Map.merge(owned_by(11..20, middle_hash))
                 |> Map.merge(owned_by(21..30, highest_hash))
                 |> Map.merge(owned_by(31..32, nil))
      end

      # The RPC node gives the same event twice. The repeated event changes
      # nothing.
      test "writes one row for a repeated event", %{json_rpc_named_arguments: json_rpc_named_arguments} do
        blocks = seed_blocks(1..12)
        seed_cursors()

        confirmation_transaction_hash = to_string(transaction_hash())

        log =
          build_send_root_updated_log(
            rollup_block_hash(blocks, 10),
            confirmation_transaction_hash,
            @confirmation_l1_block
          )

        expect_parent_chain([log, log])

        run_main(state(json_rpc_named_arguments))

        assert rows() == [{10, confirmation_transaction_hash}]
        assert Repo.aggregate(LifecycleTransaction, :count) == 1
      end

      # Two different parent chain transactions confirm the same rollup block. The
      # row keeps the event which the discovery wrote first. The lifecycle
      # transaction of the second event stays in the database, but no row refers
      # to it.
      test "keeps the first event of two events with the same top", %{
        json_rpc_named_arguments: json_rpc_named_arguments
      } do
        blocks = seed_blocks(1..12)
        seed_cursors()

        first_hash = to_string(transaction_hash())
        second_hash = to_string(transaction_hash())

        expect_parent_chain([
          build_send_root_updated_log(rollup_block_hash(blocks, 10), first_hash, @lower_confirmation_l1_block),
          build_send_root_updated_log(rollup_block_hash(blocks, 10), second_hash, @confirmation_l1_block)
        ])

        run_main(state(json_rpc_named_arguments))

        assert rows() == [{10, first_hash}]
        assert owners(0..12) == Map.merge(owned_by(0..10, first_hash), owned_by(11..12, nil))
        assert not is_nil(lifecycle_transaction(second_hash))
      end

      # The table has a row for the rollup block 10. An event confirms the rollup
      # block 0. The new row takes the block 0 from the row of the block 10.
      test "writes a row for the rollup block 0", %{json_rpc_named_arguments: json_rpc_named_arguments} do
        blocks = seed_blocks(0..12)
        seed_cursors()

        known_confirmation = insert_confirmation(@earlier_confirmation_l1_block)
        known_confirmation_hash = to_string(known_confirmation.hash)
        insert_row(10, known_confirmation)

        confirmation_transaction_hash = to_string(transaction_hash())

        expect_parent_chain([
          build_send_root_updated_log(
            rollup_block_hash(blocks, 0),
            confirmation_transaction_hash,
            @confirmation_l1_block
          )
        ])

        run_main(state(json_rpc_named_arguments))

        assert rows() == [{0, confirmation_transaction_hash}, {10, known_confirmation_hash}]

        assert owners(0..12) ==
                 owned_by(0..0, confirmation_transaction_hash)
                 |> Map.merge(owned_by(1..10, known_confirmation_hash))
                 |> Map.merge(owned_by(11..12, nil))
      end

      # The table has a row for the rollup block 20. An event confirms the rollup
      # block 10, which is below the highest `top`. The new row takes the lower
      # part of the blocks of the row of the block 20. The statuses of the
      # L2-to-L1 messages do not change, because the highest `top` does not
      # change.
      test "writes a row below the highest top and keeps the marks of the messages", %{
        json_rpc_named_arguments: json_rpc_named_arguments
      } do
        blocks = seed_blocks(1..22)
        seed_cursors()

        known_confirmation = insert_confirmation(@earlier_confirmation_l1_block)
        known_confirmation_hash = to_string(known_confirmation.hash)
        insert_row(20, known_confirmation)

        # This message has the status `:sent` although its block is confirmed. The
        # message fetcher indexed it late. The discovery does not examine the
        # messages when the highest `top` does not change.
        late_message = insert_sent_message_from_l2(5)

        confirmation_transaction_hash = to_string(transaction_hash())

        expect_parent_chain([
          build_send_root_updated_log(
            rollup_block_hash(blocks, 10),
            confirmation_transaction_hash,
            @confirmation_l1_block
          )
        ])

        run_main(state(json_rpc_named_arguments))

        assert rows() == [{10, confirmation_transaction_hash}, {20, known_confirmation_hash}]

        assert owners(0..22) ==
                 owned_by(0..10, confirmation_transaction_hash)
                 |> Map.merge(owned_by(11..20, known_confirmation_hash))
                 |> Map.merge(owned_by(21..22, nil))

        assert message_status(late_message) == :sent
      end

      # The confirmed rollup block is not indexed yet. The discovery gets its
      # number from the rollup RPC node.
      test "gets the number of a rollup block which is not indexed from the rollup RPC node", %{
        json_rpc_named_arguments: json_rpc_named_arguments
      } do
        seed_blocks(1..9)
        seed_cursors()

        unindexed_block_hash = to_string(block_hash())
        confirmation_transaction_hash = to_string(transaction_hash())

        expect_parent_chain(
          [build_send_root_updated_log(unindexed_block_hash, confirmation_transaction_hash, @confirmation_l1_block)],
          rollup_blocks: %{unindexed_block_hash => 10}
        )

        run_main(state(json_rpc_named_arguments))

        assert rows() == [{10, confirmation_transaction_hash}]
        assert owners(0..12) == Map.merge(owned_by(0..10, confirmation_transaction_hash), owned_by(11..12, nil))
      end

      # The size of a window does not change the result. With a short size, the
      # main process reads the same parent chain blocks in several windows, one
      # window in each run.
      test "gives the same rows when the events are in several windows", %{
        json_rpc_named_arguments: json_rpc_named_arguments
      } do
        blocks = seed_blocks(1..22)
        seed_cursors()

        lower_hash = to_string(transaction_hash())
        upper_hash = to_string(transaction_hash())

        expect_parent_chain([
          build_send_root_updated_log(rollup_block_hash(blocks, 10), lower_hash, @lowest_confirmation_l1_block),
          build_send_root_updated_log(rollup_block_hash(blocks, 20), upper_hash, @confirmation_l1_block)
        ])

        state = state(json_rpc_named_arguments, logs_block_range: @short_logs_block_range)

        Enum.reduce_while(1..10, state, fn _, state ->
          state = run_main(state)

          if cursor(:main) == @safe_l1_block, do: {:halt, state}, else: {:cont, state}
        end)

        assert cursor(:main) == @safe_l1_block
        assert rows() == [{10, lower_hash}, {20, upper_hash}]

        assert owners(0..22) ==
                 owned_by(0..10, lower_hash)
                 |> Map.merge(owned_by(11..20, upper_hash))
                 |> Map.merge(owned_by(21..22, nil))
      end
    end
  end
end
