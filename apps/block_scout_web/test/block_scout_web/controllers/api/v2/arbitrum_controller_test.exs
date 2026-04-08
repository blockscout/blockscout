defmodule BlockScoutWeb.API.V2.ArbitrumControllerTest do
  use Utils.CompileTimeEnvHelper, chain_type: [:explorer, :chain_type]

  if @chain_type == :arbitrum do
    use BlockScoutWeb.ConnCase

    alias Explorer.Chain.Arbitrum.L1Batch

    describe "/main-page/arbitrum/batches/committed" do
      test "returns committed batches", %{conn: conn} do
        batches = insert_list(3, :arbitrum_l1_batch)

        request = get(conn, "/api/v2/main-page/arbitrum/batches/committed")
        assert response = json_response(request, 200)

        assert length(response["items"]) == 3

        # Response is ordered by batch number descending
        sorted_batches = Enum.sort_by(batches, & &1.number, :desc)

        for {batch, item} <- Enum.zip(sorted_batches, response["items"]) do
          compare_batch(batch, item)
        end
      end

      test "returns empty list when no committed batches exist", %{conn: conn} do
        request = get(conn, "/api/v2/main-page/arbitrum/batches/committed")
        assert response = json_response(request, 200)
        assert response["items"] == []
      end

      test "returns at most 10 committed batches", %{conn: conn} do
        insert_list(12, :arbitrum_l1_batch)

        request = get(conn, "/api/v2/main-page/arbitrum/batches/committed")
        assert response = json_response(request, 200)

        assert length(response["items"]) == 10
      end
    end

    describe "/main-page/arbitrum/messages/to-rollup" do
      test "returns recent L1-to-L2 messages", %{conn: conn} do
        messages = insert_list(3, :arbitrum_message, direction: :to_l2, status: :relayed)

        request = get(conn, "/api/v2/main-page/arbitrum/messages/to-rollup")
        assert response = json_response(request, 200)

        assert length(response["items"]) == 3

        sorted_messages = Enum.sort_by(messages, & &1.message_id, :desc)

        for {msg, item} <- Enum.zip(sorted_messages, response["items"]) do
          assert to_string(msg.originating_transaction_hash) == item["origination_transaction_hash"]
          assert to_string(msg.completion_transaction_hash) == item["completion_transaction_hash"]
          assert msg.originating_transaction_block_number == item["origination_transaction_block_number"]
        end
      end

      test "returns empty list when no messages exist", %{conn: conn} do
        request = get(conn, "/api/v2/main-page/arbitrum/messages/to-rollup")
        assert response = json_response(request, 200)
        assert response["items"] == []
      end

      test "returns at most 6 messages", %{conn: conn} do
        insert_list(8, :arbitrum_message, direction: :to_l2, status: :relayed)

        request = get(conn, "/api/v2/main-page/arbitrum/messages/to-rollup")
        assert response = json_response(request, 200)

        assert length(response["items"]) == 6
      end
    end

    describe "/main-page/arbitrum/batches/latest-number" do
      test "returns latest batch number", %{conn: conn} do
        insert(:arbitrum_l1_batch, number: 5)
        insert(:arbitrum_l1_batch, number: 10)

        request = get(conn, "/api/v2/main-page/arbitrum/batches/latest-number")
        assert json_response(request, 200) == 10
      end

      test "returns 0 when no batches exist", %{conn: conn} do
        request = get(conn, "/api/v2/main-page/arbitrum/batches/latest-number")
        assert json_response(request, 200) == 0
      end
    end

    defp compare_batch(%L1Batch{} = batch, json) do
      batch = Explorer.Repo.preload(batch, :commitment_transaction)

      assert batch.number == json["number"]
      assert batch.transactions_count == json["transactions_count"]
      assert batch.end_block - batch.start_block + 1 == json["blocks_count"]

      commitment_tx = batch.commitment_transaction
      commitment_json = json["commitment_transaction"]

      assert to_string(commitment_tx.hash) == commitment_json["hash"]
      assert commitment_tx.block_number == commitment_json["block_number"]
      assert DateTime.to_iso8601(commitment_tx.timestamp) == commitment_json["timestamp"]
      assert to_string(commitment_tx.status) == commitment_json["status"]
    end
  end
end
