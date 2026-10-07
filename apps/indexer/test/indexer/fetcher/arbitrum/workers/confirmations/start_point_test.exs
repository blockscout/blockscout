# SPDX-License-Identifier: LicenseRef-Blockscout
if Application.get_env(:explorer, :chain_type) == :arbitrum do
  defmodule Indexer.Fetcher.Arbitrum.Workers.Confirmations.StartPointTest do
    use Indexer.Fetcher.Arbitrum.Workers.Confirmations.TestCase

    import ExUnit.CaptureLog

    # See `Indexer.Fetcher.Arbitrum.Workers.Confirmations.TestCase` for the
    # conventions this suite of files follows.

    # At the first run, the processes read their cursors from the database. If no
    # cursor exists, the start point is the parent chain block of the commitment
    # of the latest batch. The processes write both cursors before the first
    # window. If no batch exists, the discovery waits.
    describe "the start point of the discovery" do
      # The database holds the cursors of an earlier run. The processes use them.
      test "uses the cursors of the database", %{json_rpc_named_arguments: json_rpc_named_arguments} do
        blocks = seed_blocks(1..12)
        seed_cursors(@earlier_confirmation_l1_block, @earlier_confirmation_l1_block + 1)
        insert_row(5, insert_confirmation(@earlier_confirmation_l1_block - 10))

        confirmation_transaction_hash = to_string(transaction_hash())

        # The event is above the main cursor of the database and below the start
        # point which the latest batch would give.
        expect_parent_chain([
          build_send_root_updated_log(
            rollup_block_hash(blocks, 10),
            confirmation_transaction_hash,
            @earlier_confirmation_l1_block + 10
          )
        ])

        state = run_main(state(json_rpc_named_arguments))

        assert cursor(:main) == @safe_l1_block
        assert state.task_data.historical_confirmations.cursor == @earlier_confirmation_l1_block + 1
        assert Enum.member?(rows(), {10, confirmation_transaction_hash})
      end

      # The database holds no cursor and a batch. The start point is the parent
      # chain block of the commitment of the batch. The main cursor gets the block
      # below the start point, and the backfill cursor gets the start point.
      test "writes both cursors from the latest batch before the first window", %{
        json_rpc_named_arguments: json_rpc_named_arguments
      } do
        seed_latest_batch(@start_point)
        expect_parent_chain([])

        state = run_backfill(state(json_rpc_named_arguments, logs_block_range: 50))

        assert cursor(:main) == @main_cursor
        assert cursor(:backfill) == @backfill_cursor - 50
        assert state.task_data.new_confirmations.cursor == @main_cursor
      end

      # The latest batch is the batch with the highest number. Its commitment gives
      # the start point, also when an older batch has a higher commitment block.
      test "takes the commitment of the batch with the highest number", %{
        json_rpc_named_arguments: json_rpc_named_arguments
      } do
        seed_latest_batch(@start_point + 5)
        seed_latest_batch(@start_point)
        expect_no_rpc()

        # The main process waits because the table is empty. The cursors are
        # written before the wait.
        state = run_main(state(json_rpc_named_arguments))

        assert cursor(:main) == @main_cursor
        assert cursor(:backfill) == @backfill_cursor
        assert state.task_data.new_confirmations.cursor == @main_cursor
        assert state.task_data.historical_confirmations.cursor == @backfill_cursor
      end

      # The database holds no cursor and no batch. The discovery waits, writes a
      # log message, and sends no request.
      test "waits and writes a log message when no batch exists", %{
        json_rpc_named_arguments: json_rpc_named_arguments
      } do
        expect_no_rpc()

        log =
          capture_log(fn ->
            state = run_main(state(json_rpc_named_arguments))
            assert is_nil(state.task_data.new_confirmations.cursor)

            state = run_backfill(state(json_rpc_named_arguments))
            assert is_nil(state.task_data.historical_confirmations.cursor)
            refute Tasks.historical_confirmations_discovery_completed?(state)
          end)

        assert log =~ "waits for the first batch"
        assert is_nil(cursor(:main))
        assert is_nil(cursor(:backfill))
      end

      # A restart does not compute the start point again. The database holds the
      # cursors and a newer batch. The processes use the cursors.
      test "does not compute the start point again after a restart", %{
        json_rpc_named_arguments: json_rpc_named_arguments
      } do
        seed_cursors(@earlier_confirmation_l1_block, @earlier_confirmation_l1_block + 1)
        seed_latest_batch(@start_point)
        expect_parent_chain([])

        state = run_backfill(state(json_rpc_named_arguments, logs_block_range: 50))

        assert cursor(:main) == @earlier_confirmation_l1_block
        assert cursor(:backfill) == @earlier_confirmation_l1_block + 1 - 50
        assert state.task_data.new_confirmations.cursor == @earlier_confirmation_l1_block
      end
    end
  end
end
