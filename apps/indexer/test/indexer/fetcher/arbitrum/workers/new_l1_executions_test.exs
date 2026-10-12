# SPDX-License-Identifier: LicenseRef-Blockscout
if Application.get_env(:explorer, :chain_type) == :arbitrum do
  defmodule Indexer.Fetcher.Arbitrum.Workers.NewL1ExecutionsTest do
    use Indexer.Fetcher.Arbitrum.Workers.Confirmations.TestCase

    alias Indexer.Fetcher.Arbitrum.Workers.NewL1Executions

    # See `Indexer.Fetcher.Arbitrum.Workers.Confirmations.TestCase` for the
    # conventions this suite of files follows. A scenario of this file has three
    # parts:
    #   - one state of the database: the rows of the table of confirmations, the
    #     cursor of the backfill process of the confirmations discovery, the end
    #     block of the historical executions discovery, and the confirmed
    #     L2-to-L1 messages which wait for their executions
    #   - one set of `OutBoxTransactionExecuted` events which the parent chain
    #     holds
    #   - the result which the discovery must produce: the execution of each
    #     message, the end block, and whether the discovery is complete
    #
    # The lower bound of the historical executions discovery is the parent chain
    # block of the confirmation which owns the first indexed rollup block. The
    # discovery does not read the parent chain below the bound. While the
    # backfill process runs, the bound can move down, and the discovery must not
    # stop at it.

    # The end block of the historical executions discovery when the scenario
    # starts above the bound.
    @executions_end_block 160

    # The parent chain block of the confirmation which the backfill process finds
    # after the first one. The bound moves down to this block.
    @earliest_confirmation_l1_block 130

    # Builds the state of the executions discovery. `backfill_cursor` is the
    # cursor of the backfill process of the confirmations discovery. The tracker
    # holds this cursor in the state after the first run of that process.
    defp executions_state(json_rpc_named_arguments, end_block, backfill_cursor) do
      state = state(json_rpc_named_arguments)

      %{
        state
        | task_data:
            state.task_data
            |> Map.put(:historical_executions, %{end_block: end_block})
            |> Map.put(:historical_confirmations, %{cursor: backfill_cursor})
      }
    end

    defp run_historical(state) do
      {:ok, new_state} = NewL1Executions.discover_historical_l1_messages_executions(state)
      new_state
    end

    describe "the lower bound of the historical executions discovery" do
      # The table of confirmations is empty, and the backfill process of the
      # confirmations discovery runs. The bound is unknown. The discovery reads
      # nothing: the execution in the parent chain stays unknown, and the end
      # block does not move.
      test "waits while the backfill process runs and the table of confirmations is empty", %{
        json_rpc_named_arguments: json_rpc_named_arguments
      } do
        message = insert_confirmed_message_from_l2(7)
        execution_transaction_hash = to_string(transaction_hash())

        expect_parent_chain([],
          executions: [
            build_outbox_transaction_executed_log(7, execution_transaction_hash, @executions_end_block - 1)
          ]
        )

        state = run_historical(executions_state(json_rpc_named_arguments, @executions_end_block, @backfill_cursor))

        assert is_nil(execution(message))
        assert message_status(message) == :confirmed
        assert state.task_data.historical_executions.end_block == @executions_end_block
        refute NewL1Executions.historical_executions_discovery_completed?(state)
      end

      # The table of confirmations is empty, and the backfill process is
      # complete. The bound is `l1_rollup_init_block`. The discovery reads down
      # to it and finds the execution in the init block.
      test "reads down to the rollup init block after the backfill process when the table of confirmations is empty",
           %{json_rpc_named_arguments: json_rpc_named_arguments} do
        message = insert_confirmed_message_from_l2(7)
        execution_transaction_hash = to_string(transaction_hash())

        expect_parent_chain([],
          executions: [
            build_outbox_transaction_executed_log(7, execution_transaction_hash, @l1_rollup_init_block)
          ]
        )

        state = run_historical(executions_state(json_rpc_named_arguments, @executions_end_block, @l1_rollup_init_block))

        assert execution(message) == execution_transaction_hash
        assert message_status(message) == :relayed
        assert state.task_data.historical_executions.end_block == @l1_rollup_init_block - 1
        assert NewL1Executions.historical_executions_discovery_completed?(state)
      end

      # A row owns the first indexed rollup block, and the backfill process runs.
      # The bound is the parent chain block of the confirmation of that row. The
      # discovery finds the execution in the block of the bound, and not the one
      # below it. The discovery is not complete, because the bound can move down.
      test "reads down to the bound while the backfill process runs", %{
        json_rpc_named_arguments: json_rpc_named_arguments
      } do
        insert_row(10, insert_confirmation(@earlier_confirmation_l1_block))
        message_at_bound = insert_confirmed_message_from_l2(7)
        message_below_bound = insert_confirmed_message_from_l2(8)
        execution_at_bound_hash = to_string(transaction_hash())
        execution_below_bound_hash = to_string(transaction_hash())

        expect_parent_chain([],
          executions: [
            build_outbox_transaction_executed_log(7, execution_at_bound_hash, @earlier_confirmation_l1_block),
            build_outbox_transaction_executed_log(8, execution_below_bound_hash, @earlier_confirmation_l1_block - 1)
          ]
        )

        state = run_historical(executions_state(json_rpc_named_arguments, @executions_end_block, @backfill_cursor))

        assert execution(message_at_bound) == execution_at_bound_hash
        assert message_status(message_at_bound) == :relayed
        assert is_nil(execution(message_below_bound))
        assert message_status(message_below_bound) == :confirmed
        assert state.task_data.historical_executions.end_block == @earlier_confirmation_l1_block - 1
        refute NewL1Executions.historical_executions_discovery_completed?(state)
      end

      # The end block is below the bound, and the backfill process runs. The
      # discovery reads nothing and keeps its end block. The execution below the
      # bound stays unknown until the backfill process moves the bound down.
      test "waits at the bound while the backfill process runs", %{
        json_rpc_named_arguments: json_rpc_named_arguments
      } do
        insert_row(10, insert_confirmation(@earlier_confirmation_l1_block))
        message = insert_confirmed_message_from_l2(8)
        execution_transaction_hash = to_string(transaction_hash())

        expect_parent_chain([],
          executions: [
            build_outbox_transaction_executed_log(8, execution_transaction_hash, @earlier_confirmation_l1_block - 1)
          ]
        )

        end_block = @earlier_confirmation_l1_block - 1

        state = run_historical(executions_state(json_rpc_named_arguments, end_block, @backfill_cursor))

        assert is_nil(execution(message))
        assert message_status(message) == :confirmed
        assert state.task_data.historical_executions.end_block == end_block
        refute NewL1Executions.historical_executions_discovery_completed?(state)
      end

      # The end block is below the bound of the previous run, and the backfill
      # process found an earlier confirmation of the first indexed rollup block.
      # The bound moved down. The discovery finds the execution between the new
      # bound and the end block, and not the one below the new bound.
      test "finds the executions above a bound which moved down", %{
        json_rpc_named_arguments: json_rpc_named_arguments
      } do
        insert_row(5, insert_confirmation(@earliest_confirmation_l1_block))
        insert_row(10, insert_confirmation(@earlier_confirmation_l1_block))
        message_above_bound = insert_confirmed_message_from_l2(8)
        message_below_bound = insert_confirmed_message_from_l2(9)
        execution_above_bound_hash = to_string(transaction_hash())
        execution_below_bound_hash = to_string(transaction_hash())

        expect_parent_chain([],
          executions: [
            build_outbox_transaction_executed_log(8, execution_above_bound_hash, @earliest_confirmation_l1_block + 10),
            build_outbox_transaction_executed_log(9, execution_below_bound_hash, @earliest_confirmation_l1_block - 1)
          ]
        )

        end_block = @earlier_confirmation_l1_block - 1

        state = run_historical(executions_state(json_rpc_named_arguments, end_block, @backfill_cursor))

        assert execution(message_above_bound) == execution_above_bound_hash
        assert message_status(message_above_bound) == :relayed
        assert is_nil(execution(message_below_bound))
        assert message_status(message_below_bound) == :confirmed
        assert state.task_data.historical_executions.end_block == @earliest_confirmation_l1_block - 1
        refute NewL1Executions.historical_executions_discovery_completed?(state)
      end

      # The end block is below the bound, and the backfill process is complete.
      # The bound does not move any more. The discovery reads nothing and is
      # complete. An execution below the bound cannot belong to an indexed
      # rollup block.
      test "is complete below the bound after the backfill process", %{
        json_rpc_named_arguments: json_rpc_named_arguments
      } do
        insert_row(10, insert_confirmation(@earlier_confirmation_l1_block))
        message = insert_confirmed_message_from_l2(8)
        execution_transaction_hash = to_string(transaction_hash())

        expect_parent_chain([],
          executions: [
            build_outbox_transaction_executed_log(8, execution_transaction_hash, @earlier_confirmation_l1_block - 1)
          ]
        )

        end_block = @earlier_confirmation_l1_block - 1

        state = run_historical(executions_state(json_rpc_named_arguments, end_block, @l1_rollup_init_block))

        assert is_nil(execution(message))
        assert message_status(message) == :confirmed
        assert state.task_data.historical_executions.end_block == end_block
        assert NewL1Executions.historical_executions_discovery_completed?(state)
      end
    end
  end
end
