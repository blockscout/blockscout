# SPDX-License-Identifier: LicenseRef-Blockscout
if Application.get_env(:explorer, :chain_type) == :arbitrum do
  defmodule Indexer.Fetcher.Arbitrum.Workers.Confirmations.TwoUnitsTest do
    use Indexer.Fetcher.Arbitrum.Workers.Confirmations.TestCase

    # See `Indexer.Fetcher.Arbitrum.Workers.Confirmations.TestCase` for the
    # conventions this suite of files follows.

    # A scenario of two units holds an event below the start point and an event
    # in the window of the main process. At the first start, the table is empty
    # and the main process waits. Thus the backfill process reads the window below
    # the start point first. Then the main process reads its window. The tests
    # examine the owners after each unit.
    #
    # The final table does not depend on which process found an event. Thus the
    # tests hold the two events in the normal order and in the inverted order.
    describe "a window of the backfill process and then a window of the main process" do
      # The backfill process finds the lower confirmation. Its row owns the blocks
      # from 0. Then the main process finds the upper confirmation, and its row
      # takes the blocks above the lower `top`.
      test "gives the upper blocks to the confirmation which the main process finds", %{
        json_rpc_named_arguments: json_rpc_named_arguments
      } do
        blocks = seed_blocks(1..22)
        seed_cursors(@main_cursor, @backfill_cursor)

        lower_hash = to_string(transaction_hash())
        upper_hash = to_string(transaction_hash())
        lower_message = insert_sent_message_from_l2(5)
        upper_message = insert_sent_message_from_l2(15)

        expect_parent_chain([
          build_send_root_updated_log(rollup_block_hash(blocks, 10), lower_hash, @earlier_confirmation_l1_block),
          build_send_root_updated_log(rollup_block_hash(blocks, 20), upper_hash, @confirmation_l1_block)
        ])

        state = run_backfill(state(json_rpc_named_arguments))

        assert rows() == [{10, lower_hash}]
        assert owners(0..22) == Map.merge(owned_by(0..10, lower_hash), owned_by(11..22, nil))
        assert message_status(lower_message) == :confirmed
        assert message_status(upper_message) == :sent

        run_main(state)

        assert rows() == [{10, lower_hash}, {20, upper_hash}]

        assert owners(0..22) ==
                 owned_by(0..10, lower_hash)
                 |> Map.merge(owned_by(11..20, upper_hash))
                 |> Map.merge(owned_by(21..22, nil))

        assert message_status(lower_message) == :confirmed
        assert message_status(upper_message) == :confirmed
      end

      # The inverted order: the older parent chain block holds the confirmation of
      # the higher rollup block. The backfill process finds the upper confirmation,
      # and its row owns the blocks from 0. Then the main process finds the lower
      # confirmation, and its row takes the lower blocks.
      test "gives the lower blocks to the confirmation which the main process finds", %{
        json_rpc_named_arguments: json_rpc_named_arguments
      } do
        blocks = seed_blocks(1..22)
        seed_cursors(@main_cursor, @backfill_cursor)

        lower_hash = to_string(transaction_hash())
        upper_hash = to_string(transaction_hash())
        lower_message = insert_sent_message_from_l2(5)

        expect_parent_chain([
          build_send_root_updated_log(rollup_block_hash(blocks, 20), upper_hash, @earlier_confirmation_l1_block),
          build_send_root_updated_log(rollup_block_hash(blocks, 10), lower_hash, @confirmation_l1_block)
        ])

        state = run_backfill(state(json_rpc_named_arguments))

        assert rows() == [{20, upper_hash}]
        assert owners(0..22) == Map.merge(owned_by(0..20, upper_hash), owned_by(21..22, nil))
        assert message_status(lower_message) == :confirmed

        run_main(state)

        assert rows() == [{10, lower_hash}, {20, upper_hash}]

        assert owners(0..22) ==
                 owned_by(0..10, lower_hash)
                 |> Map.merge(owned_by(11..20, upper_hash))
                 |> Map.merge(owned_by(21..22, nil))

        assert message_status(lower_message) == :confirmed
      end

      # The rollup has no confirmation. The main process waits while the backfill
      # process reads down to `l1_rollup_init_block`. Then the main process reads
      # its window. Thus the wait has an end.
      test "starts the main process after the backfill process reaches the rollup init block", %{
        json_rpc_named_arguments: json_rpc_named_arguments
      } do
        seed_cursors(@main_cursor, @backfill_cursor)
        expect_parent_chain([])

        state = state(json_rpc_named_arguments, logs_block_range: @backfill_cursor - @l1_rollup_init_block)

        state = run_main(state)
        assert cursor(:main) == @main_cursor

        state = run_backfill(state)
        assert cursor(:backfill) == @l1_rollup_init_block
        assert Tasks.historical_confirmations_discovery_completed?(state)

        run_main(state)
        assert cursor(:main) == @safe_l1_block
      end
    end
  end
end
