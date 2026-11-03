# SPDX-License-Identifier: LicenseRef-Blockscout
if Application.get_env(:explorer, :chain_type) == :arbitrum do
  defmodule Indexer.Fetcher.Arbitrum.Workers.NewL1ExecutionsTest do
    use Indexer.Fetcher.Arbitrum.Workers.Confirmations.TestCase

    alias Indexer.Fetcher.Arbitrum.Workers.NewL1Executions

    # See `Indexer.Fetcher.Arbitrum.Workers.Confirmations.TestCase` for the
    # conventions this suite of files follows. A scenario of this file has three
    # parts:
    #   - one state of the database: the batch which holds the first indexed
    #     rollup block, the cursor of the historical executions discovery, the
    #     known executions, the end block of the discovery, and the confirmed
    #     L2-to-L1 messages which wait for their executions
    #   - one set of `OutBoxTransactionExecuted` events which the parent chain
    #     holds
    #   - the result which the discovery must produce: the execution of each
    #     message, the end block, the cursor, and whether the discovery is
    #     complete
    #
    # The lower bound of the historical executions discovery is the parent chain
    # block of the commitment of the batch which holds the first indexed rollup
    # block, and not below `l1_rollup_init_block`. The discovery does not read
    # the parent chain below the bound. While the batch is unknown, the bound is
    # `l1_rollup_init_block`, and the discovery does not wait for the batch. The
    # discovery keeps its cursor in the database: the first block of the last
    # window. A restart continues from the cursor.

    # The end block of the historical executions discovery when the scenario
    # starts above the bound.
    @executions_end_block 160

    # The parent chain block of the commitment of the batch which holds the first
    # indexed rollup block. The lower bound of the discovery is this block.
    @commitment_l1_block 140

    # Builds the state of the executions discovery. `end_block` is `nil` before
    # the first run of the discovery, as the tracker sets it.
    defp executions_state(json_rpc_named_arguments, end_block, options \\ []) do
      state = state(json_rpc_named_arguments, options)

      %{
        state
        | task_data:
            state.task_data
            |> Map.put(:historical_executions, %{end_block: end_block})
            |> Map.put(:new_executions, %{start_block: Keyword.get(options, :new_executions_start_block, 0)})
      }
    end

    # Runs the historical executions discovery once and gives the new state.
    defp run_historical(state) do
      {:ok, new_state} = NewL1Executions.discover_historical_l1_messages_executions(state)
      new_state
    end

    defp end_block(state), do: state.task_data.historical_executions.end_block

    describe "the lower bound of the historical executions discovery" do
      # The batch which holds the first indexed rollup block is known. The bound
      # is the parent chain block of its commitment. The discovery finds the
      # execution in the block of the bound, and not the one below it.
      test "reads down to the commitment block of the batch of the first indexed rollup block", %{
        json_rpc_named_arguments: json_rpc_named_arguments
      } do
        seed_batch_of_rollup_block(@rollup_first_block, @commitment_l1_block)
        message_at_bound = insert_confirmed_message_from_l2(7)
        message_below_bound = insert_confirmed_message_from_l2(8)
        execution_at_bound_hash = to_string(transaction_hash())
        execution_below_bound_hash = to_string(transaction_hash())

        expect_parent_chain([],
          executions: [
            build_outbox_transaction_executed_log(7, execution_at_bound_hash, @commitment_l1_block),
            build_outbox_transaction_executed_log(8, execution_below_bound_hash, @commitment_l1_block - 1)
          ]
        )

        state = run_historical(executions_state(json_rpc_named_arguments, @executions_end_block))

        assert execution(message_at_bound) == execution_at_bound_hash
        assert message_status(message_at_bound) == :relayed
        assert is_nil(execution(message_below_bound))
        assert message_status(message_below_bound) == :confirmed
        assert end_block(state) == @commitment_l1_block - 1
        assert executions_cursor() == @commitment_l1_block
        assert NewL1Executions.historical_executions_discovery_completed?(state)
      end

      # The batch which holds the first indexed rollup block is not in the
      # database. The bound is `l1_rollup_init_block`. The discovery does not
      # wait for the batch: it reads down to the init block, and it is complete.
      test "reads down to the init block while the batch of the first indexed rollup block is unknown", %{
        json_rpc_named_arguments: json_rpc_named_arguments
      } do
        message_at_bound = insert_confirmed_message_from_l2(7)
        message_below_bound = insert_confirmed_message_from_l2(8)
        execution_at_bound_hash = to_string(transaction_hash())
        execution_below_bound_hash = to_string(transaction_hash())

        expect_parent_chain([],
          executions: [
            build_outbox_transaction_executed_log(7, execution_at_bound_hash, @l1_rollup_init_block),
            build_outbox_transaction_executed_log(8, execution_below_bound_hash, @l1_rollup_init_block - 1)
          ]
        )

        state = run_historical(executions_state(json_rpc_named_arguments, @executions_end_block))

        assert execution(message_at_bound) == execution_at_bound_hash
        assert message_status(message_at_bound) == :relayed
        assert is_nil(execution(message_below_bound))
        assert message_status(message_below_bound) == :confirmed
        assert end_block(state) == @l1_rollup_init_block - 1
        assert executions_cursor() == @l1_rollup_init_block
        assert NewL1Executions.historical_executions_discovery_completed?(state)
      end

      # The first indexed rollup block is 0, which is in no batch. The bound is
      # `l1_rollup_init_block`, also when a batch which holds the rollup block 1
      # is known. The rollup contract makes the confirmation of the block 0 in
      # the init block, so no execution exists below it.
      test "reads down to the init block if the first indexed rollup block is 0", %{
        json_rpc_named_arguments: json_rpc_named_arguments
      } do
        seed_batch_of_rollup_block(1, @commitment_l1_block)
        message = insert_confirmed_message_from_l2(7)
        execution_transaction_hash = to_string(transaction_hash())

        expect_parent_chain([],
          executions: [
            build_outbox_transaction_executed_log(7, execution_transaction_hash, @l1_rollup_init_block)
          ]
        )

        state =
          run_historical(executions_state(json_rpc_named_arguments, @executions_end_block, rollup_first_block: 0))

        assert execution(message) == execution_transaction_hash
        assert message_status(message) == :relayed
        assert end_block(state) == @l1_rollup_init_block - 1
        assert executions_cursor() == @l1_rollup_init_block
        assert NewL1Executions.historical_executions_discovery_completed?(state)
      end

      # The first window runs while the batch is unknown, so the bound is the
      # init block. Then the batches discovery finds the batch, with its
      # commitment above the end block. The bound moves up to the commitment
      # block. The second run reads nothing, keeps the end block, and the
      # discovery is complete. The execution below the commitment block cannot
      # belong to an indexed rollup block.
      test "moves the bound up when the batch of the first indexed rollup block appears later", %{
        json_rpc_named_arguments: json_rpc_named_arguments
      } do
        message = insert_confirmed_message_from_l2(7)
        execution_transaction_hash = to_string(transaction_hash())

        expect_parent_chain([],
          executions: [
            build_outbox_transaction_executed_log(7, execution_transaction_hash, @executions_end_block - 3)
          ]
        )

        state =
          run_historical(
            executions_state(json_rpc_named_arguments, @executions_end_block, logs_block_range: @short_logs_block_range)
          )

        assert end_block(state) == @executions_end_block - 3
        assert executions_cursor() == @executions_end_block - 2
        refute NewL1Executions.historical_executions_discovery_completed?(state)

        seed_batch_of_rollup_block(@rollup_first_block, @executions_end_block - 2)

        state = run_historical(state)

        assert is_nil(execution(message))
        assert message_status(message) == :confirmed
        assert end_block(state) == @executions_end_block - 3
        assert executions_cursor() == @executions_end_block - 2
        assert NewL1Executions.historical_executions_discovery_completed?(state)
      end

      # The end block is one block above the bound, and a window holds several
      # blocks. The discovery reads the window down to the bound, and not below
      # it. After this window, the discovery is complete.
      test "is complete after it reads the window at the bound", %{
        json_rpc_named_arguments: json_rpc_named_arguments
      } do
        seed_batch_of_rollup_block(@rollup_first_block, @commitment_l1_block)
        message_at_bound = insert_confirmed_message_from_l2(7)
        message_below_bound = insert_confirmed_message_from_l2(8)
        execution_at_bound_hash = to_string(transaction_hash())
        execution_below_bound_hash = to_string(transaction_hash())

        expect_parent_chain([],
          executions: [
            build_outbox_transaction_executed_log(7, execution_at_bound_hash, @commitment_l1_block),
            build_outbox_transaction_executed_log(8, execution_below_bound_hash, @commitment_l1_block - 1)
          ]
        )

        state =
          run_historical(
            executions_state(json_rpc_named_arguments, @commitment_l1_block + 1,
              logs_block_range: @short_logs_block_range
            )
          )

        assert execution(message_at_bound) == execution_at_bound_hash
        assert message_status(message_at_bound) == :relayed
        assert is_nil(execution(message_below_bound))
        assert message_status(message_below_bound) == :confirmed
        assert end_block(state) == @commitment_l1_block - 1
        assert executions_cursor() == @commitment_l1_block
        assert NewL1Executions.historical_executions_discovery_completed?(state)
      end

      # Before the first run of the discovery, the end block is `nil`, as the
      # tracker sets it. The discovery is not complete, whatever the bound is.
      test "is not complete before the first run", %{json_rpc_named_arguments: json_rpc_named_arguments} do
        seed_batch_of_rollup_block(@rollup_first_block, @commitment_l1_block)
        expect_no_rpc()

        refute NewL1Executions.historical_executions_discovery_completed?(
                 executions_state(json_rpc_named_arguments, nil)
               )
      end
    end

    describe "the cursor of the historical executions discovery" do
      # The parent chain holds no execution. Each window writes the cursor: the
      # first block of the window. The second run continues below the first
      # window.
      test "writes the cursor after each window, also after a window without executions", %{
        json_rpc_named_arguments: json_rpc_named_arguments
      } do
        expect_parent_chain([])

        state =
          run_historical(
            executions_state(json_rpc_named_arguments, @executions_end_block, logs_block_range: @short_logs_block_range)
          )

        assert end_block(state) == @executions_end_block - 3
        assert executions_cursor() == @executions_end_block - 2

        state = run_historical(state)

        assert end_block(state) == @executions_end_block - 6
        assert executions_cursor() == @executions_end_block - 5
        refute NewL1Executions.historical_executions_discovery_completed?(state)
      end

      # The database holds the cursor of an earlier run and an execution which
      # that run found below the cursor. After a restart, the end block is `nil`.
      # The discovery continues below the cursor, and not below the known
      # execution. The execution at the cursor is in a window which the earlier
      # run read, so the discovery does not find it again.
      test "continues from the stored cursor after a restart", %{
        json_rpc_named_arguments: json_rpc_named_arguments
      } do
        seed_executions_cursor(@executions_end_block)
        insert_execution(5, @commitment_l1_block)
        message_below_cursor = insert_confirmed_message_from_l2(7)
        message_at_cursor = insert_confirmed_message_from_l2(8)
        execution_below_cursor_hash = to_string(transaction_hash())
        execution_at_cursor_hash = to_string(transaction_hash())

        expect_parent_chain([],
          executions: [
            build_outbox_transaction_executed_log(7, execution_below_cursor_hash, @executions_end_block - 1),
            build_outbox_transaction_executed_log(8, execution_at_cursor_hash, @executions_end_block)
          ]
        )

        state =
          run_historical(executions_state(json_rpc_named_arguments, nil, logs_block_range: @short_logs_block_range))

        assert execution(message_below_cursor) == execution_below_cursor_hash
        assert message_status(message_below_cursor) == :relayed
        assert is_nil(execution(message_at_cursor))
        assert message_status(message_at_cursor) == :confirmed
        assert end_block(state) == @executions_end_block - 4
        assert executions_cursor() == @executions_end_block - 3
      end

      # The database holds an execution and no cursor, as after an upgrade from
      # a release without the cursor. The discovery starts below the known
      # execution. The execution above the known one belongs to the windows
      # which the earlier release read.
      test "starts below the earliest known execution if no cursor exists", %{
        json_rpc_named_arguments: json_rpc_named_arguments
      } do
        insert_execution(5, @executions_end_block)
        message_below_known = insert_confirmed_message_from_l2(7)
        message_above_known = insert_confirmed_message_from_l2(8)
        execution_below_known_hash = to_string(transaction_hash())
        execution_above_known_hash = to_string(transaction_hash())

        expect_parent_chain([],
          executions: [
            build_outbox_transaction_executed_log(7, execution_below_known_hash, @executions_end_block - 1),
            build_outbox_transaction_executed_log(8, execution_above_known_hash, @executions_end_block + 1)
          ]
        )

        state =
          run_historical(executions_state(json_rpc_named_arguments, nil, logs_block_range: @short_logs_block_range))

        assert execution(message_below_known) == execution_below_known_hash
        assert message_status(message_below_known) == :relayed
        assert is_nil(execution(message_above_known))
        assert message_status(message_above_known) == :confirmed
        assert end_block(state) == @executions_end_block - 4
        assert executions_cursor() == @executions_end_block - 3
      end

      # The database holds no execution and no cursor, as at the first start of
      # an instance. The discovery starts below `l1_start_block`.
      test "starts below the start block of the parent chain if no execution and no cursor exist", %{
        json_rpc_named_arguments: json_rpc_named_arguments
      } do
        message = insert_confirmed_message_from_l2(7)
        execution_transaction_hash = to_string(transaction_hash())

        expect_parent_chain([],
          executions: [
            build_outbox_transaction_executed_log(7, execution_transaction_hash, @l1_start_block - 1)
          ]
        )

        state =
          run_historical(executions_state(json_rpc_named_arguments, nil, logs_block_range: @short_logs_block_range))

        assert execution(message) == execution_transaction_hash
        assert message_status(message) == :relayed
        assert end_block(state) == @l1_start_block - 4
        assert executions_cursor() == @l1_start_block - 3
      end

      # The database holds the cursor of an earlier run at the bound: the
      # earlier run read the window at the bound. After a restart, the end block
      # is `nil`. The first run loads the cursor, reads nothing, and the
      # discovery is complete.
      test "is complete at the first run after a restart if the stored cursor is at the bound", %{
        json_rpc_named_arguments: json_rpc_named_arguments
      } do
        seed_batch_of_rollup_block(@rollup_first_block, @commitment_l1_block)
        seed_executions_cursor(@commitment_l1_block)
        expect_no_rpc()

        state = run_historical(executions_state(json_rpc_named_arguments, nil))

        assert end_block(state) == @commitment_l1_block - 1
        assert executions_cursor() == @commitment_l1_block
        assert NewL1Executions.historical_executions_discovery_completed?(state)
      end

      # The discovery of new executions reads the parent chain up from its start
      # block to the latest block. It finds the execution, but it does not write
      # the cursor of the historical discovery.
      test "is not written by the discovery of new executions", %{
        json_rpc_named_arguments: json_rpc_named_arguments
      } do
        message = insert_confirmed_message_from_l2(7)
        execution_transaction_hash = to_string(transaction_hash())

        expect_parent_chain([],
          executions: [
            build_outbox_transaction_executed_log(7, execution_transaction_hash, @latest_l1_block - 1)
          ]
        )

        {:ok, state} =
          NewL1Executions.discover_new_l1_messages_executions(
            executions_state(json_rpc_named_arguments, nil, new_executions_start_block: @confirmation_l1_block)
          )

        assert execution(message) == execution_transaction_hash
        assert message_status(message) == :relayed
        assert state.task_data.new_executions.start_block == @latest_l1_block + 1
        assert is_nil(executions_cursor())
      end
    end

    describe "the executions below the window where the backfill process stopped" do
      # The window below the start point of the backfill process is 145..194.
      @backfill_logs_block_range 50

      # The scenario of the review. The window of the backfill process holds an
      # event with a `top` below the first indexed rollup block, so the process
      # stops early. The parent chain holds a confirmation in the inverted order
      # below that window: an older block holds an event with a higher `top`.
      # The backfill process does not read it, and the table does not confirm
      # the rollup blocks of that event. An execution of a message from these
      # rollup blocks lies between the commitment block of the batch of the
      # first indexed rollup block and the lowest confirmation which the
      # backfill process found. The bound of the executions discovery is the
      # commitment block, so the discovery finds the execution after the
      # backfill process stopped.
      test "are found after the backfill process stopped early", %{
        json_rpc_named_arguments: json_rpc_named_arguments
      } do
        rollup_first_block = 5
        inverted_confirmation_l1_block = @commitment_l1_block + 4
        execution_l1_block = @commitment_l1_block + 6

        blocks = seed_blocks(3..35)
        seed_cursors(@main_cursor, @backfill_cursor)
        seed_batch_of_rollup_block(rollup_first_block, @commitment_l1_block)
        message = insert_confirmed_message_from_l2(7)
        stop_confirmation_hash = to_string(transaction_hash())
        inverted_confirmation_hash = to_string(transaction_hash())
        execution_transaction_hash = to_string(transaction_hash())

        expect_parent_chain(
          [
            build_send_root_updated_log(
              rollup_block_hash(blocks, 3),
              stop_confirmation_hash,
              @earlier_confirmation_l1_block
            ),
            build_send_root_updated_log(
              rollup_block_hash(blocks, 30),
              inverted_confirmation_hash,
              inverted_confirmation_l1_block
            )
          ],
          executions: [
            build_outbox_transaction_executed_log(7, execution_transaction_hash, execution_l1_block)
          ]
        )

        state =
          run_backfill(
            executions_state(json_rpc_named_arguments, @executions_end_block,
              rollup_first_block: rollup_first_block,
              logs_block_range: @backfill_logs_block_range
            )
          )

        assert cursor(:backfill) == @l1_rollup_init_block
        assert rows() == [{3, stop_confirmation_hash}]
        assert is_nil(owner(30))
        assert Tasks.historical_confirmations_discovery_completed?(state)

        state = run_historical(state)

        assert execution(message) == execution_transaction_hash
        assert message_status(message) == :relayed
        assert end_block(state) == @commitment_l1_block - 1
        assert executions_cursor() == @commitment_l1_block
        assert NewL1Executions.historical_executions_discovery_completed?(state)
      end
    end
  end
end
