# SPDX-License-Identifier: LicenseRef-Blockscout
if Application.get_env(:explorer, :chain_type) == :arbitrum do
  defmodule Indexer.Fetcher.Arbitrum.Workers.Confirmations.LowestL1BlockTest do
    use Indexer.Fetcher.Arbitrum.Workers.Confirmations.TestCase

    # See `Indexer.Fetcher.Arbitrum.Workers.Confirmations.TestCase` for the
    # conventions this suite of files follows.

    # Other historical discoveries use `lowest_l1_block_for_confirmations/1` as
    # their lower bound. A result that is too high stops them early. A result that
    # is too low makes them read the parent chain down to `l1_rollup_init_block`.
    # The result is the lowest parent chain block among the rows with a `top` not
    # below `rollup_first_block`, also in the inverted order. While the backfill
    # process runs, the result can move down, and it never moves up. The result
    # is `nil` if no row confirms `rollup_first_block`, also after the backfill
    # process. Then the other discoveries wait.
    describe "lowest_l1_block_for_confirmations/1" do
      # The backfill cursor is above `l1_rollup_init_block`, and a row confirms
      # `rollup_first_block`. The backfill can find an earlier confirmation later,
      # but the row never gives a block below the true one. The result is the
      # parent chain block of the confirmation of that row.
      test "gives the block of the confirmation of the first rollup block while the backfill process runs", %{
        json_rpc_named_arguments: json_rpc_named_arguments
      } do
        seed_cursors(@main_cursor, @backfill_cursor)
        insert_row(10, insert_confirmation(@earlier_confirmation_l1_block))
        expect_parent_chain([])

        state = run_main(state(json_rpc_named_arguments))

        refute Tasks.historical_confirmations_discovery_completed?(state)
        assert Tasks.lowest_l1_block_for_confirmations(state) == @earlier_confirmation_l1_block
      end

      # The backfill cursor is above `l1_rollup_init_block`, and the table is
      # empty. The bound is unknown.
      test "gives nil while the backfill process runs and the table is empty", %{
        json_rpc_named_arguments: json_rpc_named_arguments
      } do
        seed_cursors(@main_cursor, @backfill_cursor)
        expect_no_rpc()

        state = run_main(state(json_rpc_named_arguments))

        refute Tasks.historical_confirmations_discovery_completed?(state)
        assert is_nil(Tasks.lowest_l1_block_for_confirmations(state))
      end

      # The backfill is complete, and two rows confirm `rollup_first_block` in the
      # normal order. The result is the parent chain block of the confirmation of
      # the row with the lowest `top`, which is the earlier one.
      test "gives the block of the confirmation of the first rollup block after the backfill", %{
        json_rpc_named_arguments: json_rpc_named_arguments
      } do
        seed_cursors(@main_cursor, @l1_rollup_init_block)
        insert_row(10, insert_confirmation(@earlier_confirmation_l1_block))
        insert_row(20, insert_confirmation(@confirmation_l1_block))
        expect_no_rpc()

        state = run_backfill(state(json_rpc_named_arguments, rollup_first_block: 5))

        assert Tasks.historical_confirmations_discovery_completed?(state)
        assert Tasks.lowest_l1_block_for_confirmations(state) == @earlier_confirmation_l1_block
      end

      # The backfill is complete, and two rows confirm `rollup_first_block` in the
      # inverted order. The row with the lowest `top` holds the later
      # confirmation. The result is the parent chain block of the earlier
      # confirmation, because an execution can exist between the two.
      test "gives the block of the earlier confirmation in the inverted order", %{
        json_rpc_named_arguments: json_rpc_named_arguments
      } do
        seed_cursors(@main_cursor, @l1_rollup_init_block)
        insert_row(10, insert_confirmation(@confirmation_l1_block))
        insert_row(20, insert_confirmation(@earlier_confirmation_l1_block))
        expect_no_rpc()

        state = run_backfill(state(json_rpc_named_arguments, rollup_first_block: 5))

        assert Tasks.historical_confirmations_discovery_completed?(state)
        assert Tasks.lowest_l1_block_for_confirmations(state) == @earlier_confirmation_l1_block
      end

      # The backfill is complete, but no row confirms `rollup_first_block`. The
      # backfill stopped early at an event with a `top` below it. The bound is
      # unknown until the main process finds a confirmation of the block.
      test "gives nil after the backfill when the first rollup block is not confirmed", %{
        json_rpc_named_arguments: json_rpc_named_arguments
      } do
        seed_cursors(@main_cursor, @l1_rollup_init_block)
        insert_row(10, insert_confirmation(@earlier_confirmation_l1_block))
        expect_no_rpc()

        state = run_backfill(state(json_rpc_named_arguments, rollup_first_block: 11))

        assert Tasks.historical_confirmations_discovery_completed?(state)
        assert is_nil(Tasks.lowest_l1_block_for_confirmations(state))
      end
    end
  end
end
