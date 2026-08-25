# SPDX-License-Identifier: LicenseRef-Blockscout
if Application.compile_env(:explorer, :chain_type) == :arbitrum do
  defmodule Indexer.Fetcher.Arbitrum.Workers.Confirmations.RollupBlocksTest do
    use EthereumJSONRPC.Case, async: false
    use Explorer.DataCase

    import Mox

    alias Indexer.Fetcher.Arbitrum.Workers.Confirmations.RollupBlocks

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

        result =
          RollupBlocks.extend_confirmations(
            confirmation_desc(top_block, confirmation_l1_transaction_hash),
            outbox_config(json_rpc_named_arguments),
            batch.start_block
          )

        assert Enum.map(result, & &1.block_number) |> Enum.sort() ==
                 Enum.to_list(batch.start_block..batch.end_block)

        assert Enum.all?(result, &(&1.confirmation_transaction == confirmation_l1_transaction_hash))
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

        result =
          RollupBlocks.extend_confirmations(
            confirmation_desc(top_block, confirmation_l1_transaction_hash),
            outbox_config(json_rpc_named_arguments),
            batch.start_block
          )

        assert Enum.map(result, & &1.block_number) |> Enum.sort() == Enum.to_list(15..batch.end_block)
        assert Enum.all?(result, &(&1.confirmation_transaction == confirmation_l1_transaction_hash))
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

        result =
          RollupBlocks.extend_confirmations(
            confirmation_desc(top_block, confirmation_l1_transaction_hash),
            outbox_config(json_rpc_named_arguments),
            batch.start_block
          )

        assert result == []
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

    # No SendRootUpdated event is found for the requested L1 block range, mimicking a
    # confirmation recorded at a higher parent-chain block in an earlier discovery pass.
    defp expect_no_boundary_logs do
      EthereumJSONRPC.Mox
      |> expect(:json_rpc, fn %{method: "eth_getLogs"}, _options -> {:ok, []} end)
    end
  end
end
