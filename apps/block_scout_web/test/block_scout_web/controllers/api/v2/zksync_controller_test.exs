# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule BlockScoutWeb.API.V2.ZkSyncControllerTest do
  use BlockScoutWeb.ConnCase
  use Utils.CompileTimeEnvHelper, chain_type: [:explorer, :chain_type]

  if @chain_type == :zksync do
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

    describe "/zksync/batches" do
      test "returns an empty list when there are no batches", %{conn: conn} do
        request = get(conn, "/api/v2/zksync/batches")
        assert response = json_response(request, 200)

        assert response["items"] == []
        assert response["next_page_params"] == nil
      end

      test "returns batches with all lifecycle status values and aggregated transactions count",
           %{conn: conn} do
        sealed_batch = insert(:zksync_transaction_batch)

        commit_tx = insert(:zksync_lifecycle_transaction)
        sent_batch = insert(:zksync_transaction_batch, commit_id: commit_tx.id)

        prove_tx = insert(:zksync_lifecycle_transaction)

        validated_batch =
          insert(:zksync_transaction_batch, commit_id: commit_tx.id, prove_id: prove_tx.id)

        execute_tx = insert(:zksync_lifecycle_transaction)

        executed_batch =
          insert(:zksync_transaction_batch,
            commit_id: commit_tx.id,
            prove_id: prove_tx.id,
            execute_id: execute_tx.id
          )

        request = get(conn, "/api/v2/zksync/batches")
        assert response = json_response(request, 200)

        # Order is desc: number — executed_batch was inserted last, so it appears first.
        assert response["next_page_params"] == nil
        assert length(response["items"]) == 4

        items_by_number = Enum.into(response["items"], %{}, &{&1["number"], &1})

        sealed_item = Map.fetch!(items_by_number, sealed_batch.number)
        assert sealed_item["status"] == "Sealed on L2"
        assert sealed_item["commit_transaction_hash"] == nil
        assert sealed_item["prove_transaction_hash"] == nil
        assert sealed_item["execute_transaction_hash"] == nil

        assert sealed_item["transactions_count"] ==
                 sealed_batch.l1_transaction_count + sealed_batch.l2_transaction_count

        sent_item = Map.fetch!(items_by_number, sent_batch.number)
        assert sent_item["status"] == "Sent to L1"
        assert sent_item["commit_transaction_hash"] == to_string(commit_tx.hash)
        assert sent_item["commit_transaction_timestamp"] == DateTime.to_iso8601(commit_tx.timestamp)

        validated_item = Map.fetch!(items_by_number, validated_batch.number)
        assert validated_item["status"] == "Validated on L1"
        assert validated_item["prove_transaction_hash"] == to_string(prove_tx.hash)

        executed_item = Map.fetch!(items_by_number, executed_batch.number)
        assert executed_item["status"] == "Executed on L1"
        assert executed_item["execute_transaction_hash"] == to_string(execute_tx.hash)

        assert executed_item["execute_transaction_timestamp"] ==
                 DateTime.to_iso8601(execute_tx.timestamp)
      end

      test "paginates batches with next_page_params on second page", %{conn: conn} do
        batches = insert_list(51, :zksync_transaction_batch)

        request = get(conn, "/api/v2/zksync/batches")
        assert response = json_response(request, 200)

        assert Enum.count(response["items"]) == 50
        assert response["next_page_params"] != nil

        request_2nd = get(conn, "/api/v2/zksync/batches", response["next_page_params"])
        assert response_2nd = json_response(request_2nd, 200)

        assert Enum.count(response_2nd["items"]) == 1
        assert response_2nd["next_page_params"] == nil

        # Order is desc: number — last inserted appears first; oldest batch is on the second page.
        assert Enum.at(response_2nd["items"], 0)["number"] == Enum.at(batches, 0).number
      end

      test "returns 422 when items_count is not a valid integer", %{conn: conn} do
        request = get(conn, "/api/v2/zksync/batches", %{"items_count" => "foo"})
        assert json_response(request, 422)
      end
    end
  end
end
