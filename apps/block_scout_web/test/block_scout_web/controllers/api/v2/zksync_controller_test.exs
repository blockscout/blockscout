# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule BlockScoutWeb.API.V2.ZkSyncControllerTest do
  use BlockScoutWeb.ConnCase
  use Utils.CompileTimeEnvHelper, chain_type: [:explorer, :chain_type]

  if @chain_type == :zksync do
    # The 5th status value, "Processed on L2", is intentionally not exercised here: it is
    # structurally unreachable from this endpoint because ZkSyncView.batch_status/1 short-
    # circuits on Map.has_key?(zksync_item, :batch_number), which is true only for
    # %Transaction{}/%Block{} items rendered via extend_*_json_response, not for the
    # %TransactionBatch{} (whose primary key is :number) returned here.
    describe "/zksync/batches/:batch_number_param" do
      test "returns batch by number with sealed status when no lifecycle transactions", %{conn: conn} do
        batch = insert(:zksync_transaction_batch)

        request = get(conn, "/api/v2/zksync/batches/#{batch.number}")
        assert response = json_response(request, 200)

        assert response["number"] == batch.number
        assert response["root_hash"] == to_string(batch.root_hash)
        assert response["l1_transactions_count"] == batch.l1_transaction_count
        assert response["l2_transactions_count"] == batch.l2_transaction_count
        assert response["l1_gas_price"] == to_string(batch.l1_gas_price.value)
        assert response["l2_fair_gas_price"] == to_string(batch.l2_fair_gas_price.value)
        assert response["start_block_number"] == batch.start_block
        assert response["end_block_number"] == batch.end_block
        assert response["status"] == "Sealed on L2"
        assert response["commit_transaction_hash"] == nil
        assert response["commit_transaction_timestamp"] == nil
        assert response["prove_transaction_hash"] == nil
        assert response["prove_transaction_timestamp"] == nil
        assert response["execute_transaction_hash"] == nil
        assert response["execute_transaction_timestamp"] == nil
      end

      test "returns batch with sent status when only commit transaction present", %{conn: conn} do
        commit_tx = insert(:zksync_lifecycle_transaction)
        batch = insert(:zksync_transaction_batch, commit_id: commit_tx.id)

        request = get(conn, "/api/v2/zksync/batches/#{batch.number}")
        assert response = json_response(request, 200)

        assert response["status"] == "Sent to L1"
        assert response["commit_transaction_hash"] == to_string(commit_tx.hash)
        assert response["commit_transaction_timestamp"] == DateTime.to_iso8601(commit_tx.timestamp)
        assert response["prove_transaction_hash"] == nil
        assert response["execute_transaction_hash"] == nil
      end

      test "returns batch with validated status when commit and prove transactions present", %{conn: conn} do
        commit_tx = insert(:zksync_lifecycle_transaction)
        prove_tx = insert(:zksync_lifecycle_transaction)
        batch = insert(:zksync_transaction_batch, commit_id: commit_tx.id, prove_id: prove_tx.id)

        request = get(conn, "/api/v2/zksync/batches/#{batch.number}")
        assert response = json_response(request, 200)

        assert response["status"] == "Validated on L1"
        assert response["commit_transaction_hash"] == to_string(commit_tx.hash)
        assert response["prove_transaction_hash"] == to_string(prove_tx.hash)
        assert response["prove_transaction_timestamp"] == DateTime.to_iso8601(prove_tx.timestamp)
        assert response["execute_transaction_hash"] == nil
      end

      test "returns batch with executed status when all lifecycle transactions present", %{conn: conn} do
        commit_tx = insert(:zksync_lifecycle_transaction)
        prove_tx = insert(:zksync_lifecycle_transaction)
        execute_tx = insert(:zksync_lifecycle_transaction)

        batch =
          insert(:zksync_transaction_batch,
            commit_id: commit_tx.id,
            prove_id: prove_tx.id,
            execute_id: execute_tx.id
          )

        request = get(conn, "/api/v2/zksync/batches/#{batch.number}")
        assert response = json_response(request, 200)

        assert response["status"] == "Executed on L1"
        assert response["commit_transaction_hash"] == to_string(commit_tx.hash)
        assert response["commit_transaction_timestamp"] == DateTime.to_iso8601(commit_tx.timestamp)
        assert response["prove_transaction_hash"] == to_string(prove_tx.hash)
        assert response["prove_transaction_timestamp"] == DateTime.to_iso8601(prove_tx.timestamp)
        assert response["execute_transaction_hash"] == to_string(execute_tx.hash)
        assert response["execute_transaction_timestamp"] == DateTime.to_iso8601(execute_tx.timestamp)
      end

      test "returns 404 when batch is not found", %{conn: conn} do
        request = get(conn, "/api/v2/zksync/batches/999999")
        assert json_response(request, 404)
      end

      test "returns 422 when batch number is not an integer", %{conn: conn} do
        request = get(conn, "/api/v2/zksync/batches/not-a-number")
        assert json_response(request, 422)
      end
    end
  end
end
