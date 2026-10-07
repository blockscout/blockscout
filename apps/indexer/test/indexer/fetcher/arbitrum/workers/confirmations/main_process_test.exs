# SPDX-License-Identifier: LicenseRef-Blockscout
if Application.get_env(:explorer, :chain_type) == :arbitrum do
  defmodule Indexer.Fetcher.Arbitrum.Workers.Confirmations.MainProcessTest do
    use Indexer.Fetcher.Arbitrum.Workers.Confirmations.TestCase

    # See `Indexer.Fetcher.Arbitrum.Workers.Confirmations.TestCase` for the
    # conventions this suite of files follows.

    # The main process moves up the parent chain from its cursor. One run reads
    # one window: from the block after the cursor to the safe block, or to the
    # latest block when `finalized_confirmations` is `false`. After the window,
    # the cursor holds the last block of the window.
    #
    # Each test of this group examines the cursor and the rows after one run.
    describe "check_new/1 as the main process" do
      # The window holds no event. The cursor still moves to the end of the
      # window. Without this, a restart reads all empty windows again.
      test "moves the cursor to the end of a window without events", %{
        json_rpc_named_arguments: json_rpc_named_arguments
      } do
        seed_cursors()
        expect_parent_chain([])

        state = run_main(state(json_rpc_named_arguments))

        assert cursor(:main) == @safe_l1_block
        assert state.task_data.new_confirmations.cursor == @safe_l1_block
        assert rows() == []
      end

      # The window holds an event. The rows and the cursor change together.
      test "writes the rows and the cursor of a window with events", %{
        json_rpc_named_arguments: json_rpc_named_arguments
      } do
        blocks = seed_blocks(1..12)
        seed_cursors()

        confirmation_transaction_hash = to_string(transaction_hash())

        expect_parent_chain([
          build_send_root_updated_log(
            rollup_block_hash(blocks, 10),
            confirmation_transaction_hash,
            @confirmation_l1_block
          )
        ])

        state = run_main(state(json_rpc_named_arguments))

        assert cursor(:main) == @safe_l1_block
        assert state.task_data.new_confirmations.cursor == @safe_l1_block
        assert rows() == [{10, confirmation_transaction_hash}]
      end

      # The RPC node does not give the logs. The run fails, the cursor does not
      # move, and the next run reads the same window.
      test "does not move the cursor when an RPC request fails", %{
        json_rpc_named_arguments: json_rpc_named_arguments
      } do
        blocks = seed_blocks(1..12)
        seed_cursors()

        confirmation_transaction_hash = to_string(transaction_hash())

        expect_parent_chain(
          [
            build_send_root_updated_log(
              rollup_block_hash(blocks, 10),
              confirmation_transaction_hash,
              @confirmation_l1_block
            )
          ],
          logs_fail?: true
        )

        assert_raise(RuntimeError, fn -> run_main(state(json_rpc_named_arguments)) end)

        assert cursor(:main) == @main_cursor
        assert rows() == []
        assert is_nil(lifecycle_transaction(confirmation_transaction_hash))
      end

      # The discovery reads the same window again, for example after a restart
      # before the import. The second run changes nothing.
      test "changes nothing in a second run of the same window", %{
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
        rows_after_first_run = rows()
        transactions_after_first_run = Repo.all(from(t in LifecycleTransaction, order_by: t.id))

        seed_cursors()
        run_main(state(json_rpc_named_arguments))

        assert cursor(:main) == @safe_l1_block
        assert rows() == rows_after_first_run
        assert Repo.all(from(t in LifecycleTransaction, order_by: t.id)) == transactions_after_first_run
      end

      # With `finalized_confirmations` set to `false`, the window starts at the
      # lower of the block after the cursor and the safe block, and it ends at the
      # latest block. Thus the process reads the blocks above the safe block again.
      # A re-org moved the confirmation transaction to a new block: the discovery
      # updates the block number of the transaction.
      test "reads the blocks above the safe block again when finalized_confirmations is false", %{
        json_rpc_named_arguments: json_rpc_named_arguments
      } do
        blocks = seed_blocks(1..12)
        # The cursor is above the safe block: the process reached the head before.
        seed_cursors(@confirmation_l1_block + 4)

        known_confirmation = insert_confirmation(@stale_confirmation_l1_block)
        known_confirmation_hash = to_string(known_confirmation.hash)
        insert_row(10, known_confirmation)

        expect_parent_chain(
          [build_send_root_updated_log(rollup_block_hash(blocks, 10), known_confirmation_hash, @confirmation_l1_block)],
          safe: @confirmation_l1_block,
          latest: @latest_l1_block
        )

        run_main(state(json_rpc_named_arguments, finalized_confirmations: false))

        assert cursor(:main) == @latest_l1_block
        assert rows() == [{10, known_confirmation_hash}]
        assert lifecycle_transaction(known_confirmation_hash).block_number == @confirmation_l1_block
      end

      # With `finalized_confirmations` set to `true`, the window ends at the safe
      # block. If the cursor is at the safe block, there is no window.
      test "does nothing when the cursor is at the safe block", %{
        json_rpc_named_arguments: json_rpc_named_arguments
      } do
        seed_cursors(@safe_l1_block)
        expect_parent_chain([])

        state = run_main(state(json_rpc_named_arguments))

        assert cursor(:main) == @safe_l1_block
        assert state.task_data.new_confirmations.cursor == @safe_l1_block
      end

      # The table of confirmations is empty, and the backfill cursor is above
      # `l1_rollup_init_block`. The main process waits for the first event of the
      # backfill process, and it sends no request.
      test "waits while the table is empty and the backfill process runs", %{
        json_rpc_named_arguments: json_rpc_named_arguments
      } do
        seed_cursors(@main_cursor, @backfill_cursor)
        expect_no_rpc()

        state = run_main(state(json_rpc_named_arguments))

        assert cursor(:main) == @main_cursor
        assert state.task_data.new_confirmations.cursor == @main_cursor
        assert state.task_data.historical_confirmations.cursor == @backfill_cursor
      end

      # The table of confirmations is empty, but the backfill cursor reached
      # `l1_rollup_init_block`. The rollup has no confirmation below the start
      # point. The main process reads its window.
      test "does not wait when the backfill process is complete", %{
        json_rpc_named_arguments: json_rpc_named_arguments
      } do
        seed_cursors()
        expect_parent_chain([])

        run_main(state(json_rpc_named_arguments))

        assert cursor(:main) == @safe_l1_block
      end

      # The table of confirmations has a row. The main process reads its window
      # while the backfill process runs.
      test "does not wait when the table has a row", %{json_rpc_named_arguments: json_rpc_named_arguments} do
        seed_cursors(@main_cursor, @backfill_cursor)
        insert_row(10, insert_confirmation(@earlier_confirmation_l1_block))
        expect_parent_chain([])

        run_main(state(json_rpc_named_arguments))

        assert cursor(:main) == @safe_l1_block
      end
    end
  end
end
