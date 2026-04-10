defmodule BlockScoutWeb.API.V2.ArbitrumControllerTest do
  use Utils.CompileTimeEnvHelper, chain_type: [:explorer, :chain_type]

  if @chain_type == :arbitrum do
    use BlockScoutWeb.ConnCase

    alias Explorer.Chain.Arbitrum.{BatchToDaBlob, DaMultiPurposeRecord, L1Batch}

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

    describe "/arbitrum/messages/:direction" do
      test "returns to-rollup messages", %{conn: conn} do
        messages = insert_list(3, :arbitrum_message, direction: :to_l2, status: :relayed)

        request = get(conn, "/api/v2/arbitrum/messages/to-rollup")
        assert response = json_response(request, 200)

        assert length(response["items"]) == 3
        assert response["next_page_params"] == nil

        sorted_messages = Enum.sort_by(messages, & &1.message_id, :desc)

        for {msg, item} <- Enum.zip(sorted_messages, response["items"]) do
          assert msg.message_id == item["id"]
          assert to_string(msg.originator_address) == item["origination_address_hash"]
          assert to_string(msg.originating_transaction_hash) == item["origination_transaction_hash"]
          assert msg.originating_transaction_block_number == item["origination_transaction_block_number"]
          assert to_string(msg.completion_transaction_hash) == item["completion_transaction_hash"]
          assert to_string(msg.status) == item["status"]
        end
      end

      test "returns from-rollup messages", %{conn: conn} do
        messages = insert_list(3, :arbitrum_message, direction: :from_l2, status: :initiated)

        request = get(conn, "/api/v2/arbitrum/messages/from-rollup")
        assert response = json_response(request, 200)

        assert length(response["items"]) == 3
        assert response["next_page_params"] == nil

        sorted_messages = Enum.sort_by(messages, & &1.message_id, :desc)

        for {msg, item} <- Enum.zip(sorted_messages, response["items"]) do
          assert msg.message_id == item["id"]
          assert to_string(msg.status) == item["status"]
        end
      end

      test "returns empty list when no messages exist", %{conn: conn} do
        request = get(conn, "/api/v2/arbitrum/messages/to-rollup")
        assert response = json_response(request, 200)
        assert response["items"] == []
        assert response["next_page_params"] == nil
      end

      test "does not include messages from opposite direction", %{conn: conn} do
        insert_list(3, :arbitrum_message, direction: :from_l2, status: :initiated)

        request = get(conn, "/api/v2/arbitrum/messages/to-rollup")
        assert response = json_response(request, 200)
        assert response["items"] == []
      end

      test "paginates messages", %{conn: conn} do
        insert_list(51, :arbitrum_message, direction: :to_l2, status: :relayed)

        request = get(conn, "/api/v2/arbitrum/messages/to-rollup")
        assert response = json_response(request, 200)
        assert length(response["items"]) == 50
        assert response["next_page_params"] != nil

        request_2nd_page = get(conn, "/api/v2/arbitrum/messages/to-rollup", response["next_page_params"])
        assert response_2nd_page = json_response(request_2nd_page, 200)
        assert length(response_2nd_page["items"]) == 1
        assert response_2nd_page["next_page_params"] == nil
      end

      test "returns 422 for invalid direction", %{conn: conn} do
        request = get(conn, "/api/v2/arbitrum/messages/invalid")
        assert %{"errors" => _} = json_response(request, 422)
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

    describe "/arbitrum/batches" do
      test "returns empty list when no batches exist", %{conn: conn} do
        request = get(conn, "/api/v2/arbitrum/batches")
        assert response = json_response(request, 200)
        assert response["items"] == []
        assert response["next_page_params"] == nil
      end

      test "returns batches", %{conn: conn} do
        batches = insert_list(3, :arbitrum_l1_batch)

        request = get(conn, "/api/v2/arbitrum/batches")
        assert response = json_response(request, 200)

        assert length(response["items"]) == 3

        sorted_batches = Enum.sort_by(batches, & &1.number, :desc)

        for {batch, item} <- Enum.zip(sorted_batches, response["items"]) do
          compare_batch(batch, item)
        end
      end

      test "filters by batch_numbers", %{conn: conn} do
        batches = insert_list(5, :arbitrum_l1_batch)
        selected = Enum.take(batches, 2)
        selected_numbers = Enum.map(selected, & &1.number)

        query = %{"batch_numbers" => selected_numbers}
        request = get(conn, "/api/v2/arbitrum/batches", query)
        assert response = json_response(request, 200)

        assert length(response["items"]) == 2

        returned_numbers = Enum.map(response["items"], & &1["number"])
        assert Enum.sort(returned_numbers) == Enum.sort(selected_numbers)
      end

      test "paginates batches", %{conn: conn} do
        batches = insert_list(51, :arbitrum_l1_batch)

        request = get(conn, "/api/v2/arbitrum/batches")
        assert response = json_response(request, 200)

        assert length(response["items"]) == 50
        assert response["next_page_params"] != nil

        request = get(conn, "/api/v2/arbitrum/batches", response["next_page_params"])
        assert response = json_response(request, 200)

        assert length(response["items"]) == 1
        assert response["next_page_params"] == nil

        assert length(Enum.uniq_by(batches, & &1.number)) == 51
      end
    end

    describe "/arbitrum/batches/:batch_number" do
      test "returns batch by number", %{conn: conn} do
        batch = insert(:arbitrum_l1_batch)

        request = get(conn, "/api/v2/arbitrum/batches/#{batch.number}")
        assert response = json_response(request, 200)

        batch = Explorer.Repo.preload(batch, :commitment_transaction)

        assert response["number"] == batch.number
        assert response["transactions_count"] == batch.transactions_count
        assert response["start_block_number"] == batch.start_block
        assert response["end_block_number"] == batch.end_block
        assert response["before_acc_hash"] == to_string(batch.before_acc)
        assert response["after_acc_hash"] == to_string(batch.after_acc)

        commitment_json = response["commitment_transaction"]
        assert to_string(batch.commitment_transaction.hash) == commitment_json["hash"]
        assert batch.commitment_transaction.block_number == commitment_json["block_number"]

        assert response["data_availability"] != nil
        assert response["data_availability"]["batch_data_container"] == nil
      end

      test "returns batch with celestia data availability info", %{conn: conn} do
        batch = insert(:arbitrum_l1_batch, batch_container: :in_celestia)

        {:ok, data_key} = Explorer.Chain.Hash.Full.cast("0x" <> String.duplicate("ab", 32))

        Explorer.Repo.insert!(%DaMultiPurposeRecord{
          data_key: data_key,
          data_type: 0,
          batch_number: batch.number,
          data: %{
            "height" => 123_456,
            "transaction_commitment" => "0x" <> String.duplicate("cd", 32)
          }
        })

        Explorer.Repo.insert!(%BatchToDaBlob{
          batch_number: batch.number,
          data_blob_id: data_key
        })

        request = get(conn, "/api/v2/arbitrum/batches/#{batch.number}")
        assert response = json_response(request, 200)

        da = response["data_availability"]
        assert da["batch_data_container"] == "in_celestia"
        assert da["height"] == 123_456
        assert da["transaction_commitment"] == "0x" <> String.duplicate("cd", 32)
      end

      test "returns batch with in_blob4844 data availability", %{conn: conn} do
        batch = insert(:arbitrum_l1_batch, batch_container: :in_blob4844)

        request = get(conn, "/api/v2/arbitrum/batches/#{batch.number}")
        assert response = json_response(request, 200)

        da = response["data_availability"]
        assert da["batch_data_container"] == "in_blob4844"
      end

      test "returns batch with anytrust data availability info", %{conn: conn} do
        batch = insert(:arbitrum_l1_batch, batch_container: :in_anytrust)

        {:ok, data_key} = Explorer.Chain.Hash.Full.cast("0x" <> String.duplicate("a1", 32))
        {:ok, keyset_key} = Explorer.Chain.Hash.Full.cast("0x" <> String.duplicate("b2", 32))

        Explorer.Repo.insert!(%DaMultiPurposeRecord{
          data_key: data_key,
          data_type: 0,
          batch_number: batch.number,
          data: %{
            "keyset_hash" => "0x" <> String.duplicate("b2", 32),
            "data_hash" => "0x" <> String.duplicate("c3", 32),
            "timeout" => "2024-10-01T12:00:00Z",
            "signers_mask" => 3,
            "bls_signature" => "0x" <> String.duplicate("d4", 32)
          }
        })

        Explorer.Repo.insert!(%BatchToDaBlob{
          batch_number: batch.number,
          data_blob_id: data_key
        })

        Explorer.Repo.insert!(%DaMultiPurposeRecord{
          data_key: keyset_key,
          data_type: 1,
          data: %{
            "threshold" => 1,
            "pubkeys" => [
              %{"trusted" => true, "key" => "0x" <> String.duplicate("e5", 32)},
              %{
                "trusted" => false,
                "key" => "0x" <> String.duplicate("f6", 32),
                "proof" => "0x" <> String.duplicate("07", 32)
              }
            ]
          }
        })

        request = get(conn, "/api/v2/arbitrum/batches/#{batch.number}")
        assert response = json_response(request, 200)

        da = response["data_availability"]
        assert da["batch_data_container"] == "in_anytrust"
        assert da["data_hash"] == "0x" <> String.duplicate("c3", 32)
        assert da["timeout"] == "2024-10-01T12:00:00Z"
        assert da["bls_signature"] == "0x" <> String.duplicate("d4", 32)
        assert length(da["signers"]) == 2

        [signer1, signer2] = da["signers"]
        assert signer1["trusted"] == true
        assert signer1["key"] == "0x" <> String.duplicate("e5", 32)
        assert signer2["trusted"] == false
        assert signer2["proof"] != nil
      end

      test "returns batch with eigenda data availability info", %{conn: conn} do
        batch = insert(:arbitrum_l1_batch, batch_container: :in_eigenda)

        {:ok, data_key} = Explorer.Chain.Hash.Full.cast("0x" <> String.duplicate("e1", 32))

        Explorer.Repo.insert!(%DaMultiPurposeRecord{
          data_key: data_key,
          data_type: 0,
          batch_number: batch.number,
          data: %{
            "blob_header" => "0x" <> String.duplicate("f2", 32),
            "blob_verification_proof" => "0x" <> String.duplicate("03", 32)
          }
        })

        Explorer.Repo.insert!(%BatchToDaBlob{
          batch_number: batch.number,
          data_blob_id: data_key
        })

        request = get(conn, "/api/v2/arbitrum/batches/#{batch.number}")
        assert response = json_response(request, 200)

        da = response["data_availability"]
        assert da["batch_data_container"] == "in_eigenda"
        assert da["blob_header"] == "0x" <> String.duplicate("f2", 32)
        assert da["blob_verification_proof"] == "0x" <> String.duplicate("03", 32)
      end

      test "returns 404 for non-existing batch", %{conn: conn} do
        request = get(conn, "/api/v2/arbitrum/batches/0")
        assert %{"message" => "Not found"} = json_response(request, 404)
      end

      test "returns 422 for invalid batch number", %{conn: conn} do
        request = get(conn, "/api/v2/arbitrum/batches/invalid")
        assert %{"errors" => _} = json_response(request, 422)
      end
    end

    describe "/arbitrum/messages/claim/:message_id" do
      test "returns 400 for already relayed withdrawal", %{conn: conn} do
        message_id = 42

        transaction = insert(:transaction) |> with_block()

        insert(:arbitrum_message,
          direction: :from_l2,
          message_id: message_id,
          originating_transaction_hash: transaction.hash,
          status: :relayed
        )

        {:ok, fourth_topic} =
          Explorer.Chain.Hash.Full.cast("0x" <> String.pad_leading(Integer.to_string(message_id, 16), 64, "0"))

        {:ok, second_topic} =
          Explorer.Chain.Hash.Full.cast("0x" <> String.pad_leading("dead", 64, "0"))

        # ABI-encode unindexed params: [caller, arb_block_number, eth_block_number, timestamp, callvalue, data]
        log_data_bin =
          ABI.TypeEncoder.encode_raw(
            [<<0::160>>, 1, 2, 3, 0, <<>>],
            [:address, {:uint, 256}, {:uint, 256}, {:uint, 256}, {:uint, 256}, :bytes],
            :standard
          )

        {:ok, data} = Explorer.Chain.Data.cast("0x" <> Base.encode16(log_data_bin, case: :lower))

        insert(:log,
          transaction: transaction,
          block: transaction.block,
          block_number: transaction.block_number,
          first_topic: "0x3e7aafa77dbf186b7fd488006beff893744caa3c4f6f299e8a709fa2087374fc",
          second_topic: second_topic,
          fourth_topic: fourth_topic,
          data: data
        )

        request = get(conn, "/api/v2/arbitrum/messages/claim/#{message_id}")
        assert %{"message" => "withdrawal was executed already"} = json_response(request, 400)
      end

      test "returns 404 for non-existing message", %{conn: conn} do
        request = get(conn, "/api/v2/arbitrum/messages/claim/0")
        assert %{"message" => _} = json_response(request, 404)
      end

      test "returns 422 for invalid message id", %{conn: conn} do
        request = get(conn, "/api/v2/arbitrum/messages/claim/invalid")
        assert %{"errors" => _} = json_response(request, 422)
      end
    end

    # Non-empty withdrawal list and token sub-object variants require L2ToL1Tx event logs
    # plus L1 RPC calls (Outbox contract for status, ERC20 for token info) — not covered here.
    describe "/arbitrum/messages/withdrawals/:transaction_hash" do
      test "returns empty list for a transaction with no withdrawals", %{conn: conn} do
        transaction = insert(:transaction)

        request = get(conn, "/api/v2/arbitrum/messages/withdrawals/#{transaction.hash}")
        assert response = json_response(request, 200)
        assert response["items"] == []
      end

      test "returns 422 for invalid transaction hash", %{conn: conn} do
        request = get(conn, "/api/v2/arbitrum/messages/withdrawals/invalid")
        assert %{"errors" => _} = json_response(request, 422)
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
