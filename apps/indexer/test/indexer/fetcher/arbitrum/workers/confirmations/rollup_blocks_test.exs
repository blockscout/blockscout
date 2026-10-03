# SPDX-License-Identifier: LicenseRef-Blockscout
if Application.compile_env(:explorer, :chain_type) == :arbitrum do
  defmodule Indexer.Fetcher.Arbitrum.Workers.Confirmations.RollupBlocksTest do
    use EthereumJSONRPC.Case, async: false
    use Explorer.DataCase

    import Mox
    import Ecto.Query, only: [from: 2]

    import EthereumJSONRPC, only: [integer_to_quantity: 1, quantity_to_integer: 1]

    alias Explorer.Chain.Arbitrum.{BatchBlock, LifecycleTransaction}

    alias Indexer.Fetcher.Arbitrum.Workers.Confirmations.Discovery, as: ConfirmationsDiscovery
    alias Indexer.Fetcher.Arbitrum.Workers.Confirmations.RollupBlocks
    alias Indexer.Fetcher.Arbitrum.Workers.Confirmations.Tasks, as: ConfirmationsTasks

    setup :verify_on_exit!

    setup %{json_rpc_named_arguments: json_rpc_named_arguments} do
      mocked_json_rpc_named_arguments = Keyword.put(json_rpc_named_arguments, :transport, EthereumJSONRPC.Mox)

      %{json_rpc_named_arguments: mocked_json_rpc_named_arguments}
    end

    describe "extend_confirmations/3" do
      test "returns all unconfirmed blocks down to batch.start_block when the batch has no earlier boundary anywhere",
           %{json_rpc_named_arguments: json_rpc_named_arguments} do
        commitment_transaction = insert(:arbitrum_lifecycle_transaction, block_number: 100)

        batch =
          insert(:arbitrum_l1_batch, start_block: 10, end_block: 15, commitment_id: commitment_transaction.id)

        Enum.each(batch.start_block..batch.end_block, fn block_number ->
          insert(:arbitrum_batch_block, batch_number: batch.number, block_number: block_number, confirmation_id: nil)
        end)

        top_block = insert(:block, number: batch.end_block)

        confirmation_l1_transaction_hash = to_string(transaction_hash())

        expect_no_boundary_logs()

        {result, outcomes} =
          RollupBlocks.extend_confirmations(
            confirmation_desc(top_block, confirmation_l1_transaction_hash),
            outbox_config(json_rpc_named_arguments),
            batch.start_block
          )

        assert Enum.map(result, & &1.block_number) |> Enum.sort() ==
                 Enum.to_list(batch.start_block..batch.end_block)

        assert Enum.all?(result, &(&1.confirmation_transaction == confirmation_l1_transaction_hash))
        assert outcomes == %{confirmation_l1_transaction_hash => :claimed}
      end

      test "derives the lower boundary from the database when the boundary is recorded only there and rows below it are confirmed",
           %{json_rpc_named_arguments: json_rpc_named_arguments} do
        confirmed_boundary_transaction = insert(:arbitrum_lifecycle_transaction, block_number: 50)
        commitment_transaction = insert(:arbitrum_lifecycle_transaction, block_number: 100)

        batch =
          insert(:arbitrum_l1_batch, start_block: 10, end_block: 20, commitment_id: commitment_transaction.id)

        # Rows below the boundary (K = 15) are already confirmed in the database, proving the
        # boundary safe to use even though no SendRootUpdated event for it appears in the
        # scanned logs (it was recorded at a higher parent-chain block in an earlier pass).
        Enum.each(batch.start_block..14, fn block_number ->
          insert(:arbitrum_batch_block,
            batch_number: batch.number,
            block_number: block_number,
            confirmation_id: confirmed_boundary_transaction.id
          )
        end)

        Enum.each(15..batch.end_block, fn block_number ->
          insert(:arbitrum_batch_block, batch_number: batch.number, block_number: block_number, confirmation_id: nil)
        end)

        top_block = insert(:block, number: batch.end_block)

        confirmation_l1_transaction_hash = to_string(transaction_hash())

        expect_no_boundary_logs()

        {result, outcomes} =
          RollupBlocks.extend_confirmations(
            confirmation_desc(top_block, confirmation_l1_transaction_hash),
            outbox_config(json_rpc_named_arguments),
            batch.start_block
          )

        assert Enum.map(result, & &1.block_number) |> Enum.sort() == Enum.to_list(15..batch.end_block)
        assert Enum.all?(result, &(&1.confirmation_transaction == confirmation_l1_transaction_hash))
        assert outcomes == %{confirmation_l1_transaction_hash => :claimed}
      end

      test "postpones the confirmation when the rows below the candidate boundary are missing entirely",
           %{json_rpc_named_arguments: json_rpc_named_arguments} do
        commitment_transaction = insert(:arbitrum_lifecycle_transaction, block_number: 100)

        batch =
          insert(:arbitrum_l1_batch, start_block: 10, end_block: 20, commitment_id: commitment_transaction.id)

        # Rows below the candidate boundary (K = 15) are missing entirely (batch.start_block..14
        # have no arbitrum_batch_l2_blocks rows at all), unlike the confirmed-predecessor case:
        # this must NOT be mistaken for "confirmed", so the confirmation stays postponed.
        Enum.each(15..batch.end_block, fn block_number ->
          insert(:arbitrum_batch_block, batch_number: batch.number, block_number: block_number, confirmation_id: nil)
        end)

        top_block = insert(:block, number: batch.end_block)

        confirmation_l1_transaction_hash = to_string(transaction_hash())

        expect_no_boundary_logs()

        {result, outcomes} =
          RollupBlocks.extend_confirmations(
            confirmation_desc(top_block, confirmation_l1_transaction_hash),
            outbox_config(json_rpc_named_arguments),
            batch.start_block
          )

        assert result == []
        assert outcomes == %{confirmation_l1_transaction_hash => :error}
      end

      test "processes two confirmations in agreeing parent-chain/rollup order: each claims exactly its own range",
           %{json_rpc_named_arguments: json_rpc_named_arguments} do
        commitment_transaction = insert(:arbitrum_lifecycle_transaction, block_number: 1)

        batch =
          insert(:arbitrum_l1_batch, start_block: 10, end_block: 30, commitment_id: commitment_transaction.id)

        Enum.each(batch.start_block..batch.end_block, fn block_number ->
          insert(:arbitrum_batch_block, batch_number: batch.number, block_number: block_number, confirmation_id: nil)
        end)

        lower_top_block = insert(:block, number: 20)
        higher_top_block = insert(:block, number: 30)

        lower_hash = to_string(transaction_hash())
        higher_hash = to_string(transaction_hash())

        # Two separate log scans: one for the lower (earlier on the parent chain) confirmation's
        # descent, one for the higher (later on the parent chain) confirmation's descent.
        expect_no_boundary_logs()
        expect_no_boundary_logs()

        {result, outcomes} =
          RollupBlocks.extend_confirmations(
            %{
              to_string(lower_top_block.hash) => %{l1_transaction_hash: lower_hash, l1_block_num: 100},
              to_string(higher_top_block.hash) => %{l1_transaction_hash: higher_hash, l1_block_num: 200}
            },
            outbox_config(json_rpc_named_arguments),
            batch.start_block
          )

        block_numbers = Enum.map(result, & &1.block_number) |> Enum.sort()
        assert block_numbers == Enum.to_list(10..30)
        assert length(block_numbers) == length(Enum.uniq(block_numbers))

        assert Enum.all?(result, fn block ->
                 (block.block_number <= 20 and block.confirmation_transaction == lower_hash) or
                   (block.block_number > 20 and block.confirmation_transaction == higher_hash)
               end)

        assert outcomes == %{lower_hash => :claimed, higher_hash => :claimed}
      end

      test "processes two confirmations in inverted parent-chain order (issue #14720): the earlier-on-parent-chain confirmation owns the overlap",
           %{json_rpc_named_arguments: json_rpc_named_arguments} do
        commitment_transaction = insert(:arbitrum_lifecycle_transaction, block_number: 1)

        batch =
          insert(:arbitrum_l1_batch, start_block: 10, end_block: 30, commitment_id: commitment_transaction.id)

        Enum.each(batch.start_block..batch.end_block, fn block_number ->
          insert(:arbitrum_batch_block, batch_number: batch.number, block_number: block_number, confirmation_id: nil)
        end)

        # Analogous (scaled down) to the issue's concrete pair: the confirmation earlier on the
        # parent chain (L1 25373587) tops a higher rollup range (877285) than the confirmation
        # later on the parent chain (L1 25373590, rollup top 873589).
        higher_top_block = insert(:block, number: 30)
        lower_top_block = insert(:block, number: 20)

        earlier_hash = to_string(transaction_hash())
        later_hash = to_string(transaction_hash())

        # Only one descent is attempted: the earlier confirmation's. The later one is skipped
        # entirely once its top block is found to be at or below the watermark.
        expect_no_boundary_logs()

        {result, outcomes} =
          RollupBlocks.extend_confirmations(
            %{
              to_string(higher_top_block.hash) => %{l1_transaction_hash: earlier_hash, l1_block_num: 100},
              to_string(lower_top_block.hash) => %{l1_transaction_hash: later_hash, l1_block_num: 200}
            },
            outbox_config(json_rpc_named_arguments),
            batch.start_block
          )

        block_numbers = Enum.map(result, & &1.block_number) |> Enum.sort()
        assert block_numbers == Enum.to_list(10..30)
        assert length(block_numbers) == length(Enum.uniq(block_numbers))
        refute Enum.empty?(result)
        assert Enum.all?(result, &(&1.confirmation_transaction == earlier_hash))

        assert outcomes == %{earlier_hash => :claimed, later_hash => :covered}
      end

      test "processes two confirmations sharing the same L1 block (tie): the floor prevents any duplicate attribution",
           %{json_rpc_named_arguments: json_rpc_named_arguments} do
        commitment_transaction = insert(:arbitrum_lifecycle_transaction, block_number: 1)

        batch =
          insert(:arbitrum_l1_batch, start_block: 10, end_block: 30, commitment_id: commitment_transaction.id)

        Enum.each(batch.start_block..batch.end_block, fn block_number ->
          insert(:arbitrum_batch_block, batch_number: batch.number, block_number: block_number, confirmation_id: nil)
        end)

        low_top_block = insert(:block, number: 15)
        high_top_block = insert(:block, number: 25)

        low_hash = to_string(transaction_hash())
        high_hash = to_string(transaction_hash())

        # Both events share the same L1 block, so they are mutually invisible to each other's
        # log scan. Depending on map-iteration order, either one or two descents are attempted
        # (the second is skipped outright when the higher-top confirmation is processed first),
        # so the number of `eth_getLogs` calls is not fixed - a stub tolerates either.
        stub_no_boundary_logs()

        {result, outcomes} =
          RollupBlocks.extend_confirmations(
            %{
              to_string(low_top_block.hash) => %{l1_transaction_hash: low_hash, l1_block_num: 150},
              to_string(high_top_block.hash) => %{l1_transaction_hash: high_hash, l1_block_num: 150}
            },
            outbox_config(json_rpc_named_arguments),
            batch.start_block
          )

        block_numbers = Enum.map(result, & &1.block_number) |> Enum.sort()
        assert block_numbers == Enum.to_list(10..25)
        assert length(block_numbers) == length(Enum.uniq(block_numbers))

        assert Enum.all?(result, fn block ->
                 Enum.count(result, &(&1.block_number == block.block_number)) == 1
               end)

        refute :error in Map.values(outcomes)
        assert map_size(outcomes) == 2

        assert Enum.sort(Map.values(outcomes)) == [:claimed, :claimed] or
                 Enum.sort(Map.values(outcomes)) == [:claimed, :covered]
      end

      test "halts on a descent error and, after the database prerequisite is restored, correctly attributes the overlap on retry",
           %{json_rpc_named_arguments: json_rpc_named_arguments} do
        commitment_transaction = insert(:arbitrum_lifecycle_transaction, block_number: 1)

        # A placeholder confirmation for the batch's boundary rows only, so that the top-block
        # hashes can resolve to rollup block numbers (`rollup_block_hash_to_num/1` inner-joins on
        # `arbitrum_batch_l2_blocks`). The rest of the batch's rows do not exist at all yet (the
        # block fetcher has not caught up), which is the reachable `{:error, []}` path in
        # `get_unconfirmed_rollup_blocks/2`: no unconfirmed blocks are found in range while the
        # confirmed count is below the batch size.
        placeholder_transaction = insert(:arbitrum_lifecycle_transaction, block_number: 5)

        batch =
          insert(:arbitrum_l1_batch, start_block: 10, end_block: 30, commitment_id: commitment_transaction.id)

        higher_top_block = insert(:block, number: 30)
        lower_top_block = insert(:block, number: 20)

        insert(:arbitrum_batch_block,
          batch_number: batch.number,
          block_number: 30,
          confirmation_id: placeholder_transaction.id
        )

        insert(:arbitrum_batch_block,
          batch_number: batch.number,
          block_number: 20,
          confirmation_id: placeholder_transaction.id
        )

        earlier_hash = to_string(transaction_hash())
        later_hash = to_string(transaction_hash())

        confirmations = %{
          to_string(higher_top_block.hash) => %{l1_transaction_hash: earlier_hash, l1_block_num: 100},
          to_string(lower_top_block.hash) => %{l1_transaction_hash: later_hash, l1_block_num: 200}
        }

        # First call: the earlier confirmation's descent fails immediately (no unconfirmed
        # blocks found in the database at all), before any `eth_getLogs` call is made. The halt
        # means the later confirmation is never reached.
        {result, outcomes} =
          RollupBlocks.extend_confirmations(
            confirmations,
            outbox_config(json_rpc_named_arguments),
            batch.start_block
          )

        assert result == []
        assert outcomes == %{earlier_hash => :error}

        # Restore the database prerequisite: the block fetcher has now associated the batch's
        # rollup blocks (including re-opening the two boundary rows used above only to make the
        # hashes resolvable).
        Explorer.Repo.update_all(
          from(b in BatchBlock, where: b.block_number in [20, 30]),
          set: [confirmation_id: nil]
        )

        Enum.each(10..19, fn block_number ->
          insert(:arbitrum_batch_block, batch_number: batch.number, block_number: block_number, confirmation_id: nil)
        end)

        Enum.each(21..29, fn block_number ->
          insert(:arbitrum_batch_block, batch_number: batch.number, block_number: block_number, confirmation_id: nil)
        end)

        expect_no_boundary_logs()

        {retry_result, retry_outcomes} =
          RollupBlocks.extend_confirmations(
            confirmations,
            outbox_config(json_rpc_named_arguments),
            batch.start_block
          )

        block_numbers = Enum.map(retry_result, & &1.block_number) |> Enum.sort()
        assert block_numbers == Enum.to_list(10..30)
        assert length(block_numbers) == length(Enum.uniq(block_numbers))
        assert Enum.all?(retry_result, &(&1.confirmation_transaction == earlier_hash))

        assert retry_outcomes == %{earlier_hash => :claimed, later_hash => :covered}
      end
    end

    describe "convergence through Discovery.perform/5 and Tasks.check_unprocessed/2" do
      test "an inverted pair converges (:ok) in one historical window, importing the covered confirmation as a lifecycle transaction with no block attribution",
           %{json_rpc_named_arguments: json_rpc_named_arguments} do
        commitment_transaction = insert(:arbitrum_lifecycle_transaction, block_number: 100)

        batch =
          insert(:arbitrum_l1_batch, start_block: 10, end_block: 20, commitment_id: commitment_transaction.id)

        Enum.each(batch.start_block..batch.end_block, fn block_number ->
          insert(:arbitrum_batch_block, batch_number: batch.number, block_number: block_number, confirmation_id: nil)
        end)

        top_block_a = insert(:block, number: 20)
        top_block_b = insert(:block, number: 15)

        transaction_hash_a = to_string(transaction_hash())
        transaction_hash_b = to_string(transaction_hash())

        outbox_address = "0x0000000000000000000000000000000000000064"
        l1_rpc_config = l1_rpc_config(json_rpc_named_arguments)

        state = %{
          config: %{
            l1_outbox_address: outbox_address,
            l1_rollup_init_block: 1,
            l1_rpc: l1_rpc_config,
            l1_start_block: 1,
            rollup_first_block: batch.start_block
          },
          task_data: %{
            historical_confirmations: %{start_block: 250, end_block: 320}
          }
        }

        expect_send_root_updated_logs([
          send_root_updated_log(to_string(top_block_a.hash), transaction_hash_a, 300),
          send_root_updated_log(to_string(top_block_b.hash), transaction_hash_b, 310)
        ])

        # The earlier (on parent chain) confirmation's descent scan.
        expect_no_boundary_logs()

        expect_block_timestamps([300, 310])

        {retcode, new_state} = ConfirmationsTasks.check_unprocessed(state, false)

        assert retcode == :ok
        assert new_state.task_data.historical_confirmations == %{start_block: nil, end_block: nil}

        Enum.each(batch.start_block..batch.end_block, fn block_number ->
          assert %BatchBlock{confirmation_id: confirmation_id} = Repo.get(BatchBlock, block_number)
          refute is_nil(confirmation_id)

          lifecycle_transaction = Repo.get(LifecycleTransaction, confirmation_id)
          assert lifecycle_transaction.hash == hash_from_string(transaction_hash_a)
        end)

        covered_lifecycle_transaction =
          Repo.get_by!(LifecycleTransaction, hash: hash_from_string(transaction_hash_b))

        refute Repo.get_by(BatchBlock, confirmation_id: covered_lifecycle_transaction.id)

        # A second run over the same window (now that both confirmations are already imported)
        # converges instead of re-processing: no new blocks are claimed, and the result is `:ok`.
        expect_send_root_updated_logs([
          send_root_updated_log(to_string(top_block_a.hash), transaction_hash_a, 300),
          send_root_updated_log(to_string(top_block_b.hash), transaction_hash_b, 310)
        ])

        expect_block_timestamps([300, 310])

        assert ConfirmationsDiscovery.perform(outbox_address, 250, 320, l1_rpc_config, batch.start_block) == :ok
      end

      test "an unresolved top hash keeps the tick at :confirmation_missed without advancing, while the resolved confirmation's work is still imported",
           %{json_rpc_named_arguments: json_rpc_named_arguments} do
        commitment_transaction = insert(:arbitrum_lifecycle_transaction, block_number: 100)

        batch =
          insert(:arbitrum_l1_batch, start_block: 30, end_block: 40, commitment_id: commitment_transaction.id)

        Enum.each(batch.start_block..batch.end_block, fn block_number ->
          insert(:arbitrum_batch_block, batch_number: batch.number, block_number: block_number, confirmation_id: nil)
        end)

        resolved_top_block = insert(:block, number: 40)
        # No `Explorer.Chain.Block` is inserted for this hash: it can never resolve to a rollup
        # block number, mimicking a block the block fetcher has not indexed yet.
        unresolved_top_hash = to_string(block_hash())

        resolved_transaction_hash = to_string(transaction_hash())
        unresolved_transaction_hash = to_string(transaction_hash())

        outbox_address = "0x0000000000000000000000000000000000000064"
        l1_rpc_config = l1_rpc_config(json_rpc_named_arguments)

        state = %{
          config: %{
            l1_outbox_address: outbox_address,
            l1_rollup_init_block: 1,
            l1_rpc: l1_rpc_config,
            l1_start_block: 1,
            rollup_first_block: batch.start_block
          },
          task_data: %{
            historical_confirmations: %{start_block: 480, end_block: 520}
          }
        }

        expect_send_root_updated_logs([
          send_root_updated_log(to_string(resolved_top_block.hash), resolved_transaction_hash, 500),
          send_root_updated_log(unresolved_top_hash, unresolved_transaction_hash, 510)
        ])

        expect_no_boundary_logs()
        expect_block_timestamps([500, 510])

        {retcode, new_state} = ConfirmationsTasks.check_unprocessed(state, false)

        assert retcode == :confirmation_missed
        assert new_state.task_data.historical_confirmations == %{start_block: 480, end_block: 520}

        Enum.each(batch.start_block..batch.end_block, fn block_number ->
          assert %BatchBlock{confirmation_id: confirmation_id} = Repo.get(BatchBlock, block_number)
          refute is_nil(confirmation_id)
        end)

        assert Repo.get_by(LifecycleTransaction, hash: hash_from_string(resolved_transaction_hash))
        refute Repo.get_by(LifecycleTransaction, hash: hash_from_string(unresolved_transaction_hash))

        # A second run over the same (unchanged) database state must return :confirmation_missed
        # again - this is the intended "wait for the block fetcher" behavior, not the issue
        # #14720 loop, so it is not "fixed" here.
        expect_send_root_updated_logs([
          send_root_updated_log(to_string(resolved_top_block.hash), resolved_transaction_hash, 500),
          send_root_updated_log(unresolved_top_hash, unresolved_transaction_hash, 510)
        ])

        expect_block_timestamps([500, 510])

        {second_retcode, _second_state} = ConfirmationsTasks.check_unprocessed(new_state, false)

        assert second_retcode == :confirmation_missed
      end
    end

    defp confirmation_desc(top_block, confirmation_l1_transaction_hash) do
      %{
        to_string(top_block.hash) => %{
          l1_transaction_hash: confirmation_l1_transaction_hash,
          l1_block_num: 200
        }
      }
    end

    defp outbox_config(json_rpc_named_arguments) do
      %{
        logs_block_range: 1000,
        outbox_address: "0x0000000000000000000000000000000000000064",
        json_rpc_named_arguments: json_rpc_named_arguments
      }
    end

    defp l1_rpc_config(json_rpc_named_arguments) do
      %{
        json_rpc_named_arguments: json_rpc_named_arguments,
        logs_block_range: 100_000,
        chunk_size: 10,
        track_finalization: false
      }
    end

    defp hash_from_string(string_hash) do
      {:ok, hash} = Explorer.Chain.Hash.Full.cast(string_hash)
      hash
    end

    # No SendRootUpdated event is found for the requested L1 block range, mimicking a
    # confirmation recorded at a higher parent-chain block in an earlier discovery pass.
    defp expect_no_boundary_logs do
      EthereumJSONRPC.Mox
      |> expect(:json_rpc, fn %{method: "eth_getLogs"}, _options -> {:ok, []} end)
    end

    # Same as `expect_no_boundary_logs/0`, but tolerates being called zero, one, or more times -
    # for scenarios where the number of descent-level log scans depends on a nondeterministic
    # (map iteration order dependent) processing order.
    defp stub_no_boundary_logs do
      EthereumJSONRPC.Mox
      |> stub(:json_rpc, fn %{method: "eth_getLogs"}, _options -> {:ok, []} end)
    end

    defp expect_send_root_updated_logs(events) do
      EthereumJSONRPC.Mox
      |> expect(:json_rpc, fn %{method: "eth_getLogs"}, _options -> {:ok, events} end)
    end

    defp send_root_updated_log(top_rollup_block_hash, l1_transaction_hash, l1_block_num) do
      %{
        "topics" => [to_string(block_hash()), to_string(block_hash()), top_rollup_block_hash],
        "transactionHash" => l1_transaction_hash,
        "blockNumber" => integer_to_quantity(l1_block_num)
      }
    end

    defp expect_block_timestamps(l1_block_numbers) do
      EthereumJSONRPC.Mox
      |> expect(:json_rpc, fn request_list, _options when is_list(request_list) ->
        {:ok,
         Enum.map(request_list, fn %{id: id, params: [quantity, false]} ->
           block_number = quantity_to_integer(quantity)
           true = block_number in l1_block_numbers

           %{
             id: id,
             result: %{
               "number" => quantity,
               "timestamp" => integer_to_quantity(1_700_000_000)
             }
           }
         end)}
      end)
    end
  end
end
