# SPDX-License-Identifier: LicenseRef-Blockscout
if Application.get_env(:explorer, :chain_type) == :arbitrum do
  defmodule Indexer.Fetcher.Arbitrum.Workers.Confirmations.BackfillProcessTest do
    use Indexer.Fetcher.Arbitrum.Workers.Confirmations.TestCase

    # See `Indexer.Fetcher.Arbitrum.Workers.Confirmations.TestCase` for the
    # conventions this suite of files follows.

    # The backfill process moves down the parent chain from its cursor. One run
    # reads one window below the cursor. After the window, the cursor holds the
    # first block of the window. The process stops when its cursor reaches
    # `l1_rollup_init_block`, or when it finds an event with a `top` below the
    # first indexed rollup block.
    #
    # The tests of this group use a short window. The window below the start point
    # is 145..194.
    describe "check_historical/1 as the backfill process" do
      @backfill_logs_block_range 50
      @window_start @backfill_cursor - @backfill_logs_block_range

      # The window holds an event. The row owns the blocks from 0, and the cursor
      # moves to the first block of the window.
      test "writes the rows of a window and moves the cursor down", %{
        json_rpc_named_arguments: json_rpc_named_arguments
      } do
        blocks = seed_blocks(1..12)
        seed_cursors(@main_cursor, @backfill_cursor)

        confirmation_transaction_hash = to_string(transaction_hash())

        expect_parent_chain([
          build_send_root_updated_log(
            rollup_block_hash(blocks, 10),
            confirmation_transaction_hash,
            @earlier_confirmation_l1_block
          )
        ])

        state = run_backfill(state(json_rpc_named_arguments, logs_block_range: @backfill_logs_block_range))

        assert cursor(:backfill) == @window_start
        assert state.task_data.historical_confirmations.cursor == @window_start
        assert rows() == [{10, confirmation_transaction_hash}]
        assert owners(0..12) == Map.merge(owned_by(0..10, confirmation_transaction_hash), owned_by(11..12, nil))
        refute Tasks.historical_confirmations_discovery_completed?(state)
      end

      # The window holds no event. The cursor still moves down.
      test "moves the cursor to the start of a window without events", %{
        json_rpc_named_arguments: json_rpc_named_arguments
      } do
        seed_cursors(@main_cursor, @backfill_cursor)
        expect_parent_chain([])

        run_backfill(state(json_rpc_named_arguments, logs_block_range: @backfill_logs_block_range))

        assert cursor(:backfill) == @window_start
        assert rows() == []
      end

      # The window holds an event with a `top` below the first indexed rollup
      # block. The events below confirm only the rollup blocks that the instance
      # does not index. The process adds the event, and it sets its cursor to
      # `l1_rollup_init_block`. The backfill is complete.
      test "adds an event below the first rollup block and completes", %{
        json_rpc_named_arguments: json_rpc_named_arguments
      } do
        blocks = seed_blocks(3..12)
        seed_cursors(@main_cursor, @backfill_cursor)

        confirmation_transaction_hash = to_string(transaction_hash())

        expect_parent_chain([
          build_send_root_updated_log(
            rollup_block_hash(blocks, 3),
            confirmation_transaction_hash,
            @earlier_confirmation_l1_block
          )
        ])

        state =
          run_backfill(
            state(json_rpc_named_arguments, logs_block_range: @backfill_logs_block_range, rollup_first_block: 5)
          )

        assert cursor(:backfill) == @l1_rollup_init_block
        assert rows() == [{3, confirmation_transaction_hash}]
        assert owners(0..12) == Map.merge(owned_by(0..3, confirmation_transaction_hash), owned_by(4..12, nil))
        assert Tasks.historical_confirmations_discovery_completed?(state)
      end

      # The window holds an event of a known confirmation transaction with a `top`
      # not below the first indexed rollup block. In the inverted order, a lower
      # parent chain block can hold an event with a higher `top`. Thus a known
      # confirmation does not stop the process.
      test "does not stop on a known confirmation", %{json_rpc_named_arguments: json_rpc_named_arguments} do
        blocks = seed_blocks(1..12)
        seed_cursors(@main_cursor, @backfill_cursor)

        known_confirmation = insert_confirmation(@earlier_confirmation_l1_block)
        known_confirmation_hash = to_string(known_confirmation.hash)
        insert_row(10, known_confirmation)

        expect_parent_chain([
          build_send_root_updated_log(
            rollup_block_hash(blocks, 10),
            known_confirmation_hash,
            @earlier_confirmation_l1_block
          )
        ])

        state = run_backfill(state(json_rpc_named_arguments, logs_block_range: @backfill_logs_block_range))

        assert cursor(:backfill) == @window_start
        assert rows() == [{10, known_confirmation_hash}]
        refute Tasks.historical_confirmations_discovery_completed?(state)
      end

      # The window reaches `l1_rollup_init_block`. The cursor stops at this block,
      # and the backfill is complete.
      test "completes when the cursor reaches the rollup init block", %{
        json_rpc_named_arguments: json_rpc_named_arguments
      } do
        seed_cursors(@main_cursor, @l1_rollup_init_block + 10)
        expect_parent_chain([])

        state = run_backfill(state(json_rpc_named_arguments, logs_block_range: @backfill_logs_block_range))

        assert cursor(:backfill) == @l1_rollup_init_block
        assert Tasks.historical_confirmations_discovery_completed?(state)
      end

      # The cursor is at `l1_rollup_init_block` at the start, after a restart. The
      # backfill is complete, and the process sends no request.
      test "is complete when the cursor is at the rollup init block at the start", %{
        json_rpc_named_arguments: json_rpc_named_arguments
      } do
        seed_cursors(@main_cursor, @l1_rollup_init_block)
        expect_no_rpc()

        state = run_backfill(state(json_rpc_named_arguments, logs_block_range: @backfill_logs_block_range))

        assert cursor(:backfill) == @l1_rollup_init_block
        assert Tasks.historical_confirmations_discovery_completed?(state)
      end

      # The RPC node does not give the logs. The run fails, the cursor does not
      # move, and the next run reads the same window.
      test "does not move the cursor when an RPC request fails", %{
        json_rpc_named_arguments: json_rpc_named_arguments
      } do
        seed_cursors(@main_cursor, @backfill_cursor)
        expect_parent_chain([], logs_fail?: true)

        assert_raise(RuntimeError, fn ->
          run_backfill(state(json_rpc_named_arguments, logs_block_range: @backfill_logs_block_range))
        end)

        assert cursor(:backfill) == @backfill_cursor
      end

      # The process reads the same window again, for example after a restart
      # before the import. The second run changes nothing.
      test "changes nothing in a second run of the same window", %{
        json_rpc_named_arguments: json_rpc_named_arguments
      } do
        blocks = seed_blocks(1..12)
        seed_cursors(@main_cursor, @backfill_cursor)

        confirmation_transaction_hash = to_string(transaction_hash())

        expect_parent_chain([
          build_send_root_updated_log(
            rollup_block_hash(blocks, 10),
            confirmation_transaction_hash,
            @earlier_confirmation_l1_block
          )
        ])

        run_backfill(state(json_rpc_named_arguments, logs_block_range: @backfill_logs_block_range))
        rows_after_first_run = rows()

        seed_cursors(@main_cursor, @backfill_cursor)
        run_backfill(state(json_rpc_named_arguments, logs_block_range: @backfill_logs_block_range))

        assert cursor(:backfill) == @window_start
        assert rows() == rows_after_first_run
        assert Repo.aggregate(LifecycleTransaction, :count) == 1
      end
    end
  end
end
