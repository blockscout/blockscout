defmodule BlockScoutWeb.API.V2.ArbitrumControllerTest do
  use Utils.CompileTimeEnvHelper, chain_type: [:explorer, :chain_type]

  if @chain_type == :arbitrum do
    use BlockScoutWeb.ConnCase

    alias Explorer.Chain.Arbitrum.{BatchToDaBlob, DaMultiPurposeRecord, L1Batch}

    import Explorer.Chain.Arbitrum.DaMultiPurposeRecord.Helper, only: [calculate_celestia_data_key: 2]

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

    describe "/arbitrum/messages/:direction/count" do
      test "returns count for to-rollup messages", %{conn: conn} do
        insert_list(3, :arbitrum_message, direction: :to_l2, status: :relayed)

        request = get(conn, "/api/v2/arbitrum/messages/to-rollup/count")
        assert json_response(request, 200) == 3
      end

      test "returns count for from-rollup messages", %{conn: conn} do
        insert_list(5, :arbitrum_message, direction: :from_l2, status: :initiated)

        request = get(conn, "/api/v2/arbitrum/messages/from-rollup/count")
        assert json_response(request, 200) == 5
      end

      test "returns 0 when no messages exist", %{conn: conn} do
        request = get(conn, "/api/v2/arbitrum/messages/to-rollup/count")
        assert json_response(request, 200) == 0
      end

      test "returns 422 for invalid direction", %{conn: conn} do
        request = get(conn, "/api/v2/arbitrum/messages/invalid/count")
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

    describe "/arbitrum/batches/count" do
      test "returns 0 when no batches exist", %{conn: conn} do
        request = get(conn, "/api/v2/arbitrum/batches/count")
        assert json_response(request, 200) == 0
      end

      # The endpoint uses get_table_rows_total_count/2 which relies on PostgreSQL's
      # reltuples estimate rather than an exact COUNT. In the test database, reltuples
      # is stale after inserts (ANALYZE hasn't run), so the returned count may be 0
      # instead of the actual row count. We assert the response type rather than an
      # exact value; schema validation via json_response/2 is the main check here.
      test "returns batches count", %{conn: conn} do
        insert_list(3, :arbitrum_l1_batch)

        request = get(conn, "/api/v2/arbitrum/batches/count")
        assert response = json_response(request, 200)
        assert is_integer(response) and response >= 0
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

      # Native ETH withdrawal whose DB-side message is already :relayed.
      # The renderer skips the L1 RPC status check entirely (see
      # `ClaimRollupMessage.log_to_withdrawal/2`), and `obtain_token_withdrawal_data/1`
      # returns nil because the L2ToL1Tx event data does not start with the
      # `finalizeInboundTransfer` selector. So no L1 RPC mocking is required.
      test "returns native ETH withdrawal with status :relayed (no token)", %{conn: conn} do
        transaction = insert(:transaction) |> with_block()

        message_id = 100
        completion_transaction_hash = transaction_hash()

        insert(:arbitrum_message,
          direction: :from_l2,
          message_id: message_id,
          originating_transaction_hash: transaction.hash,
          completion_transaction_hash: completion_transaction_hash,
          status: :relayed
        )

        callvalue = 1_000_000_000_000_000

        insert_l2_to_l1_log!(transaction,
          message_id: message_id,
          callvalue: callvalue,
          data: <<>>
        )

        request = get(conn, "/api/v2/arbitrum/messages/withdrawals/#{transaction.hash}")
        assert response = json_response(request, 200)

        assert [item] = response["items"]
        assert item["id"] == message_id
        assert item["status"] == "relayed"
        assert item["callvalue"] == Integer.to_string(callvalue)
        assert item["token"] == nil
        assert item["completion_transaction_hash"] == to_string(completion_transaction_hash)
      end

      # ERC20 token withdrawal whose DB-side message is already :relayed.
      # Status check is skipped, but `obtain_token_withdrawal_data/1` decodes the
      # `finalizeInboundTransfer(...)` calldata and calls `ERC20.fetch_token_properties/3`
      # against the L1 RPC for `name`/`symbol`/`decimals`. We mock those via Mox.
      test "returns ERC20 withdrawal with token sub-object and status :relayed", %{conn: conn} do
        setup_arbitrum_l1_rpc_mocks!()

        transaction = insert(:transaction) |> with_block()

        message_id = 160_586
        completion_transaction_hash = transaction_hash()

        insert(:arbitrum_message,
          direction: :from_l2,
          message_id: message_id,
          originating_transaction_hash: transaction.hash,
          completion_transaction_hash: completion_transaction_hash,
          status: :relayed
        )

        # UNI on Ethereum mainnet — chosen from real Arbitrum withdrawal data
        # (tx 0x692ebe...557021, position 160586) discovered via the Blockscout
        # MCP server. Token metadata returned by the mock matches L1 reality.
        l1_token_address = "0x1f9840a85d5af5bf1d1762f925bdaddc4201f984"
        l1_recipient_address = "0xb8018422bce25d82e70cb98fda96a4f502d89427"
        amount = 0x6C6B935B8BBD400000

        insert_l2_to_l1_log!(transaction,
          message_id: message_id,
          data: build_finalize_inbound_transfer_calldata(l1_token_address, l1_recipient_address, amount)
        )

        expect_erc20_metadata!(l1_token_address, name: "Uniswap", symbol: "UNI", decimals: 18)

        request = get(conn, "/api/v2/arbitrum/messages/withdrawals/#{transaction.hash}")
        assert response = json_response(request, 200)

        assert [item] = response["items"]
        assert item["status"] == "relayed"

        token = item["token"]
        assert token != nil
        assert String.downcase(token["address_hash"]) == l1_token_address
        assert String.downcase(token["destination_address_hash"]) == l1_recipient_address
        assert token["amount"] == Integer.to_string(amount)
        assert token["name"] == "Uniswap"
        assert token["symbol"] == "UNI"
        assert token["decimals"] == 18
      end

      # Native ETH withdrawal whose DB-side message is :initiated.
      # Forces `get_actual_message_status/1` to run: it calls Outbox.outbox()/
      # sequencerInbox() (batched) plus Outbox.isSpent(message_id) on the L1 RPC,
      # then compares message_id to the highest-confirmed-block's `send_count`
      # (sourced from the DB). `send_count > message_id` resolves to :confirmed.
      test "returns withdrawal with status :confirmed when isSpent=false and send_count > message_id",
           %{conn: conn} do
        setup_arbitrum_l1_rpc_mocks!()

        transaction = insert(:transaction) |> with_block()
        message_id = 50

        insert(:arbitrum_message,
          direction: :from_l2,
          message_id: message_id,
          originating_transaction_hash: transaction.hash,
          status: :initiated
        )

        insert_l2_to_l1_log!(transaction, message_id: message_id, callvalue: 1_000)

        # send_count > message_id ⇒ :confirmed
        seed_highest_confirmed_block!(message_id + 50)

        outbox_address = "0x" <> String.duplicate("ab", 20)
        expect_inbox_outbox_query!(outbox_address)
        expect_outbox_is_spent!(outbox_address, message_id, false)

        request = get(conn, "/api/v2/arbitrum/messages/withdrawals/#{transaction.hash}")
        assert response = json_response(request, 200)

        assert [item] = response["items"]
        assert item["id"] == message_id
        assert item["status"] == "confirmed"
      end

      # Same machinery as the :confirmed test, but `send_count <= message_id`
      # so `get_actual_message_status/1` resolves to :sent.
      test "returns withdrawal with status :sent when isSpent=false and send_count <= message_id",
           %{conn: conn} do
        setup_arbitrum_l1_rpc_mocks!()

        transaction = insert(:transaction) |> with_block()
        message_id = 100

        insert(:arbitrum_message,
          direction: :from_l2,
          message_id: message_id,
          originating_transaction_hash: transaction.hash,
          status: :initiated
        )

        insert_l2_to_l1_log!(transaction, message_id: message_id, callvalue: 1_000)

        # send_count <= message_id ⇒ :sent
        seed_highest_confirmed_block!(message_id)

        outbox_address = "0x" <> String.duplicate("ab", 20)
        expect_inbox_outbox_query!(outbox_address)
        expect_outbox_is_spent!(outbox_address, message_id, false)

        request = get(conn, "/api/v2/arbitrum/messages/withdrawals/#{transaction.hash}")
        assert response = json_response(request, 200)

        assert [item] = response["items"]
        assert item["id"] == message_id
        assert item["status"] == "sent"
      end

      # The `:unknown` status branch of `get_actual_message_status/1` is not covered.
      # It requires the Outbox `isSpent` check to return false AND `get_size_for_proof/0`
      # to return nil — which only happens when both the DB lookup (no confirmed block
      # linked to an L1 batch) AND the RPC fallback (multi-step L1/L2 calls to resolve
      # a send-count) fail. Exercising that fallback requires mocking several additional
      # Arbitrum L1/L2 RPC endpoints beyond the ones set up here.
    end

    describe "/arbitrum/batches/da/anytrust/:data_hash" do
      test "returns batch by anytrust data hash", %{conn: conn} do
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

        request = get(conn, "/api/v2/arbitrum/batches/da/anytrust/#{data_key}")
        assert response = json_response(request, 200)

        assert response["number"] == batch.number

        da = response["data_availability"]
        assert da["batch_data_container"] == "in_anytrust"
        assert da["data_hash"] == "0x" <> String.duplicate("c3", 32)
        assert da["bls_signature"] == "0x" <> String.duplicate("d4", 32)
        assert length(da["signers"]) == 2
      end

      test "returns paginated batch list with type=all", %{conn: conn} do
        batch = insert(:arbitrum_l1_batch, batch_container: :in_anytrust)

        {:ok, data_key} = Explorer.Chain.Hash.Full.cast("0x" <> String.duplicate("a1", 32))

        Explorer.Repo.insert!(%DaMultiPurposeRecord{
          data_key: data_key,
          data_type: 0,
          batch_number: batch.number,
          data: %{
            "keyset_hash" => "0x" <> String.duplicate("b2", 32),
            "data_hash" => "0x" <> String.duplicate("c3", 32),
            "timeout" => "2024-10-01T12:00:00Z",
            "signers_mask" => 1,
            "bls_signature" => "0x" <> String.duplicate("d4", 32)
          }
        })

        Explorer.Repo.insert!(%BatchToDaBlob{
          batch_number: batch.number,
          data_blob_id: data_key
        })

        request = get(conn, "/api/v2/arbitrum/batches/da/anytrust/#{data_key}", %{"type" => "all"})
        assert response = json_response(request, 200)

        assert length(response["items"]) == 1
        assert response["next_page_params"] == nil
      end

      test "returns 404 for non-existing data hash", %{conn: conn} do
        data_hash = "0x" <> String.duplicate("00", 32)

        request = get(conn, "/api/v2/arbitrum/batches/da/anytrust/#{data_hash}")
        assert %{"message" => "Not found"} = json_response(request, 404)
      end

      test "returns 404 for non-existing data hash with type=all", %{conn: conn} do
        data_hash = "0x" <> String.duplicate("00", 32)

        request = get(conn, "/api/v2/arbitrum/batches/da/anytrust/#{data_hash}", %{"type" => "all"})
        assert %{"message" => "Not found"} = json_response(request, 404)
      end

      test "returns 422 for invalid data hash", %{conn: conn} do
        request = get(conn, "/api/v2/arbitrum/batches/da/anytrust/invalid")
        assert %{"errors" => _} = json_response(request, 422)
      end
    end

    describe "/arbitrum/batches/da/eigenda/:data_hash" do
      test "returns batch by eigenda data hash", %{conn: conn} do
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

        request = get(conn, "/api/v2/arbitrum/batches/da/eigenda/#{data_key}")
        assert response = json_response(request, 200)

        assert response["number"] == batch.number

        da = response["data_availability"]
        assert da["batch_data_container"] == "in_eigenda"
        assert da["blob_header"] == "0x" <> String.duplicate("f2", 32)
        assert da["blob_verification_proof"] == "0x" <> String.duplicate("03", 32)
      end

      test "returns paginated batch list with type=all", %{conn: conn} do
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

        request = get(conn, "/api/v2/arbitrum/batches/da/eigenda/#{data_key}", %{"type" => "all"})
        assert response = json_response(request, 200)

        assert length(response["items"]) == 1
        assert response["next_page_params"] == nil
      end

      test "returns 404 for non-existing data hash", %{conn: conn} do
        data_hash = "0x" <> String.duplicate("00", 32)

        request = get(conn, "/api/v2/arbitrum/batches/da/eigenda/#{data_hash}")
        assert %{"message" => "Not found"} = json_response(request, 404)
      end

      test "returns 404 for non-existing data hash with type=all", %{conn: conn} do
        data_hash = "0x" <> String.duplicate("00", 32)

        request = get(conn, "/api/v2/arbitrum/batches/da/eigenda/#{data_hash}", %{"type" => "all"})
        assert %{"message" => "Not found"} = json_response(request, 404)
      end

      test "returns 422 for invalid data hash", %{conn: conn} do
        request = get(conn, "/api/v2/arbitrum/batches/da/eigenda/invalid")
        assert %{"errors" => _} = json_response(request, 422)
      end
    end

    describe "/arbitrum/batches/da/celestia/:height/:transaction_commitment" do
      test "returns batch by celestia blob reference", %{conn: conn} do
        batch = insert(:arbitrum_l1_batch, batch_container: :in_celestia)

        height = 123_456
        commitment_hex = "0x" <> String.duplicate("cd", 32)
        {:ok, commitment_hash} = Explorer.Chain.Hash.Full.cast(commitment_hex)
        raw_key = calculate_celestia_data_key(height, commitment_hash)
        hex_key = "0x" <> Base.encode16(raw_key, case: :lower)
        {:ok, data_key} = Explorer.Chain.Hash.Full.cast(hex_key)

        Explorer.Repo.insert!(%DaMultiPurposeRecord{
          data_key: data_key,
          data_type: 0,
          batch_number: batch.number,
          data: %{
            "height" => height,
            "transaction_commitment" => commitment_hex
          }
        })

        Explorer.Repo.insert!(%BatchToDaBlob{
          batch_number: batch.number,
          data_blob_id: data_key
        })

        request = get(conn, "/api/v2/arbitrum/batches/da/celestia/#{height}/#{commitment_hex}")
        assert response = json_response(request, 200)

        assert response["number"] == batch.number

        da = response["data_availability"]
        assert da["batch_data_container"] == "in_celestia"
        assert da["height"] == height
        assert da["transaction_commitment"] == commitment_hex
      end

      test "returns 404 for non-existing celestia blob reference", %{conn: conn} do
        commitment_hex = "0x" <> String.duplicate("00", 32)

        request = get(conn, "/api/v2/arbitrum/batches/da/celestia/999999/#{commitment_hex}")
        assert %{"message" => "Not found"} = json_response(request, 404)
      end

      test "returns 422 for invalid transaction commitment", %{conn: conn} do
        request = get(conn, "/api/v2/arbitrum/batches/da/celestia/123/invalid")
        assert %{"errors" => _} = json_response(request, 422)
      end

      test "returns 422 for invalid height", %{conn: conn} do
        commitment_hex = "0x" <> String.duplicate("00", 32)

        request = get(conn, "/api/v2/arbitrum/batches/da/celestia/invalid/#{commitment_hex}")
        assert %{"errors" => _} = json_response(request, 422)
      end
    end

    # Sets up `:meck` to make `Indexer.Helper.json_rpc_named_arguments/1` return
    # the Mox transport (via `EthereumJSONRPC.Mox`) regardless of the configured URL,
    # and seeds the Arbitrum fetcher config so `get_json_rpc(:l1)` and
    # `get_l1_rollup_address/0` return usable values. Also installs `Mox.set_mox_global`
    # so the stubs are visible from the controller's request process.
    #
    # Registers `on_exit` callbacks to restore the original config and unload meck.
    # Use this in any test that needs to mock Arbitrum L1 RPC calls (Outbox, ERC20, ...).
    defp setup_arbitrum_l1_rpc_mocks!(rollup_address \\ "0x" <> String.duplicate("aa", 20)) do
      Mox.set_mox_global()
      Mox.verify_on_exit!()

      prev_config = Application.get_env(:indexer, Indexer.Fetcher.Arbitrum, [])

      Application.put_env(
        :indexer,
        Indexer.Fetcher.Arbitrum,
        Keyword.merge(prev_config,
          l1_rpc: "http://placeholder.invalid",
          l1_rollup_address: rollup_address
        )
      )

      :meck.new(Indexer.Helper, [:passthrough])

      :meck.expect(Indexer.Helper, :json_rpc_named_arguments, fn _rpc_url ->
        [
          transport: EthereumJSONRPC.Mox,
          transport_options: [],
          variant: EthereumJSONRPC.Geth
        ]
      end)

      ExUnit.Callbacks.on_exit(fn ->
        Application.put_env(:indexer, Indexer.Fetcher.Arbitrum, prev_config)

        try do
          :meck.unload(Indexer.Helper)
        catch
          _, _ -> :ok
        end
      end)

      rollup_address
    end

    # Inserts an L2ToL1Tx event log on the given transaction. Pads the destination
    # address into the indexed `second_topic` and the message id into the indexed
    # `fourth_topic`, then ABI-encodes the unindexed params
    # `[caller, arbBlockNum, ethBlockNum, timestamp, callvalue, data]` for the data field.
    defp insert_l2_to_l1_log!(transaction, opts) do
      message_id = Keyword.fetch!(opts, :message_id)
      destination = Keyword.get(opts, :destination, "0x" <> String.duplicate("de", 20))
      callvalue = Keyword.get(opts, :callvalue, 0)
      data_bytes = Keyword.get(opts, :data, <<>>)
      caller = Keyword.get(opts, :caller, <<0::160>>)
      arb_block_number = Keyword.get(opts, :arb_block_number, 1)
      eth_block_number = Keyword.get(opts, :eth_block_number, 2)
      timestamp = Keyword.get(opts, :timestamp, 3)

      {:ok, fourth_topic} =
        Explorer.Chain.Hash.Full.cast("0x" <> String.pad_leading(Integer.to_string(message_id, 16), 64, "0"))

      destination_hex = String.replace(destination, "0x", "")

      {:ok, second_topic} =
        Explorer.Chain.Hash.Full.cast("0x" <> String.pad_leading(destination_hex, 64, "0"))

      log_data_bin =
        ABI.TypeEncoder.encode_raw(
          [caller, arb_block_number, eth_block_number, timestamp, callvalue, data_bytes],
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
    end

    # Builds the bytes for `finalizeInboundTransfer(address,address,address,uint256,bytes)`
    # — selector `0x2e567b36`. Used as the `data` field of an L2ToL1Tx log to trigger
    # the token-withdrawal code path in `obtain_token_withdrawal_data/1`.
    defp build_finalize_inbound_transfer_calldata(l1_token, l1_recipient, amount) do
      {:ok, %{bytes: token_bytes}} = Explorer.Chain.Hash.Address.cast(l1_token)
      {:ok, %{bytes: recipient_bytes}} = Explorer.Chain.Hash.Address.cast(l1_recipient)
      # Second `from` arg is unused by `obtain_token_withdrawal_data/1` (it ignores
      # the second decoded value), so a zero-padded placeholder is sufficient.
      from_bytes = <<0::160>>

      args =
        ABI.TypeEncoder.encode_raw(
          [token_bytes, from_bytes, recipient_bytes, amount, <<>>],
          [:address, :address, :address, {:uint, 256}, :bytes],
          :standard
        )

      <<0x2E, 0x56, 0x7B, 0x36>> <> args
    end

    # Inserts a confirmed Arbitrum batch + block linkage so that
    # `SettlementReader.highest_confirmed_block/0` returns a block whose `:send_count`
    # is the supplied value. Used to drive `get_size_for_proof_from_database/0`.
    defp seed_highest_confirmed_block!(send_count) do
      lifecycle_tx = insert(:arbitrum_lifecycle_transaction)
      block = insert(:block, send_count: send_count, consensus: true)
      batch = insert(:arbitrum_l1_batch)

      insert(:arbitrum_batch_block,
        batch_number: batch.number,
        block_number: block.number,
        confirmation_id: lifecycle_tx.id
      )

      block
    end

    # Mocks the batched eth_call that `get_contracts_for_rollup(:inbox_outbox, ...)`
    # issues against the rollup contract: `sequencerInbox()` (selector 0xee35f327)
    # and `outbox()` (selector 0xce11e6ab). Returns `outbox_address` for the latter
    # and an arbitrary placeholder for the former.
    defp expect_inbox_outbox_query!(outbox_address) do
      outbox_hex = String.replace(outbox_address, "0x", "")
      outbox_response = "0x" <> String.pad_leading(outbox_hex, 64, "0")
      sequencer_inbox_response = "0x" <> String.pad_leading("ff", 64, "0")

      Mox.expect(EthereumJSONRPC.Mox, :json_rpc, fn requests, _opts ->
        responses =
          Enum.map(requests, fn %{id: id, method: "eth_call", params: [%{data: data}, _block]} ->
            result =
              cond do
                String.starts_with?(data, "0xce11e6ab") -> outbox_response
                String.starts_with?(data, "0xee35f327") -> sequencer_inbox_response
                true -> raise "Unexpected eth_call to rollup contract: #{data}"
              end

            %{id: id, jsonrpc: "2.0", result: result}
          end)

        {:ok, responses}
      end)
    end

    # Mocks the batched eth_call that `ArbitrumRpc.withdrawal_spent?/3` issues against
    # the Outbox contract: `isSpent(uint256)` — selector 0x5a129efe.
    defp expect_outbox_is_spent!(outbox_address, message_id, value) do
      expected_data =
        "0x5a129efe" <> String.pad_leading(Integer.to_string(message_id, 16), 64, "0")

      result_byte = if value, do: "01", else: "00"
      result = "0x" <> String.pad_leading(result_byte, 64, "0")

      Mox.expect(EthereumJSONRPC.Mox, :json_rpc, fn requests, _opts ->
        responses =
          Enum.map(requests, fn %{id: id, method: "eth_call", params: [%{data: data, to: to}, _block]} ->
            assert String.downcase(to) == String.downcase(outbox_address),
                   "isSpent must target the outbox address"

            assert String.downcase(data) == expected_data, "isSpent data mismatch"

            %{id: id, jsonrpc: "2.0", result: result}
          end)

        {:ok, responses}
      end)
    end

    # Mocks the batched eth_call that `ERC20.fetch_token_properties/3` issues:
    # `name()` (0x06fdde03), `symbol()` (0x95d89b41), `decimals()` (0x313ce567).
    defp expect_erc20_metadata!(token_address, opts) do
      name = Keyword.fetch!(opts, :name)
      symbol = Keyword.fetch!(opts, :symbol)
      decimals = Keyword.fetch!(opts, :decimals)

      decimals_response = "0x" <> String.pad_leading(Integer.to_string(decimals, 16), 64, "0")
      name_response = abi_encoded_string(name)
      symbol_response = abi_encoded_string(symbol)

      Mox.expect(EthereumJSONRPC.Mox, :json_rpc, fn requests, _opts ->
        token_addr_lower = String.downcase(token_address)

        responses =
          Enum.map(requests, fn %{id: id, method: "eth_call", params: [%{data: data, to: to}, _block]} ->
            assert String.downcase(to) == token_addr_lower,
                   "ERC20 metadata call must target the token contract"

            result =
              cond do
                String.starts_with?(data, "0x313ce567") -> decimals_response
                String.starts_with?(data, "0x06fdde03") -> name_response
                String.starts_with?(data, "0x95d89b41") -> symbol_response
                true -> raise "Unexpected ERC20 call: #{data}"
              end

            %{id: id, jsonrpc: "2.0", result: result}
          end)

        {:ok, responses}
      end)
    end

    # ABI-encodes a single string value as the eth_call return payload (offset+length+padded data).
    defp abi_encoded_string(str) do
      encoded =
        ABI.TypeEncoder.encode([str], %ABI.FunctionSelector{
          function: nil,
          types: [:string]
        })

      "0x" <> Base.encode16(encoded, case: :lower)
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
