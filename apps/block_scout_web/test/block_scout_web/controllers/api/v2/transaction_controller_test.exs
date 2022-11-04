defmodule BlockScoutWeb.API.V2.TransactionControllerTest do
  use BlockScoutWeb.ConnCase

  alias Explorer.Chain.{InternalTransaction, Log, Transaction}

  describe "/transactions" do
    test "empty txs", %{conn: conn} do
      request = get(conn, "/api/v2/transactions")

      assert response = json_response(request, 200)

      assert response["items"] == []
      assert response["next_page_params"] == nil
    end

    test "non empty txs", %{conn: conn} do
      1
      |> insert_list(:transaction)
      |> with_block()

      request = get(conn, "/api/v2/transactions")

      assert response = json_response(request, 200)
      assert Enum.count(response["items"]) == 1
      assert response["next_page_params"] == nil
    end

    test "txs with next_page_params", %{conn: conn} do
      txs =
        51
        |> insert_list(:transaction)
        |> with_block()

      request = get(conn, "/api/v2/transactions")
      assert response = json_response(request, 200)

      request_2nd_page = get(conn, "/api/v2/transactions", response["next_page_params"])
      assert response_2nd_page = json_response(request_2nd_page, 200)

      check_paginated_response(response, response_2nd_page, txs)
    end

    test "filter=pending", %{conn: conn} do
      pending_txs =
        51
        |> insert_list(:transaction)

      _mined_txs =
        51
        |> insert_list(:transaction)
        |> with_block()

      request = get(conn, "/api/v2/transactions", %{"filter" => "pending"})
      assert response = json_response(request, 200)

      request_2nd_page = get(conn, "/api/v2/transactions", response["next_page_params"])
      assert response_2nd_page = json_response(request_2nd_page, 200)

      check_paginated_response(response, response_2nd_page, pending_txs)
    end

    test "filter=validated", %{conn: conn} do
      _pending_txs =
        51
        |> insert_list(:transaction)

      mined_txs =
        51
        |> insert_list(:transaction)
        |> with_block()

      request = get(conn, "/api/v2/transactions", %{"filter" => "validated"})
      assert response = json_response(request, 200)

      request_2nd_page = get(conn, "/api/v2/transactions", response["next_page_params"])
      assert response_2nd_page = json_response(request_2nd_page, 200)

      check_paginated_response(response, response_2nd_page, mined_txs)
    end
  end

  describe "/transactions/{tx_hash}" do
    test "return 404 on non existing tx", %{conn: conn} do
      tx = build(:transaction)
      request = get(conn, "/api/v2/transactions/#{to_string(tx.hash)}")

      assert %{"message" => "Not found"} = json_response(request, 404)
    end

    test "return 422 on invalid tx hash", %{conn: conn} do
      request = get(conn, "/api/v2/transactions/0x")

      assert %{"message" => "Invalid parameter(s)"} = json_response(request, 422)
    end

    test "return existing tx", %{conn: conn} do
      tx =
        :transaction
        |> insert()
        |> with_block()

      request = get(conn, "/api/v2/transactions/" <> to_string(tx.hash))

      assert response = json_response(request, 200)
      compare_item(tx, response)
    end
  end

  describe "/transactions/{tx_hash}/internal-transactions" do
    test "return empty list on non existing tx", %{conn: conn} do
      tx = build(:transaction)
      request = get(conn, "/api/v2/transactions/#{to_string(tx.hash)}/internal-transactions")

      assert response = json_response(request, 200)
      assert response["items"] == []
      assert response["next_page_params"] == nil
    end

    test "return empty list", %{conn: conn} do
      tx =
        :transaction
        |> insert()
        |> with_block()

      request = get(conn, "/api/v2/transactions/#{to_string(tx.hash)}/internal-transactions")

      assert response = json_response(request, 200)
      assert response["items"] == []
      assert response["next_page_params"] == nil
    end

    test "return relevant internal transaction", %{conn: conn} do
      tx =
        :transaction
        |> insert()
        |> with_block()

      insert(:internal_transaction,
        transaction: tx,
        index: 0,
        block_number: tx.block_number,
        transaction_index: tx.index,
        block_hash: tx.block_hash,
        block_index: 0
      )

      internal_tx =
        insert(:internal_transaction,
          transaction: tx,
          index: 1,
          block_number: tx.block_number,
          transaction_index: tx.index,
          block_hash: tx.block_hash,
          block_index: 1
        )

      tx_1 =
        :transaction
        |> insert()
        |> with_block()

      0..5
      |> Enum.map(fn index ->
        insert(:internal_transaction,
          transaction: tx_1,
          index: index,
          block_number: tx_1.block_number,
          transaction_index: tx_1.index,
          block_hash: tx_1.block_hash,
          block_index: index
        )
      end)

      request = get(conn, "/api/v2/transactions/#{to_string(tx.hash)}/internal-transactions")

      assert response = json_response(request, 200)
      assert Enum.count(response["items"]) == 1
      assert response["next_page_params"] == nil
      compare_item(internal_tx, Enum.at(response["items"], 0))
    end

    test "return internal transaction with next_page_params", %{conn: conn} do
      tx =
        :transaction
        |> insert()
        |> with_block()

      insert(:internal_transaction,
        transaction: tx,
        index: 0,
        block_number: tx.block_number,
        transaction_index: tx.index,
        block_hash: tx.block_hash,
        block_index: 0
      )

      internal_txs =
        51..1
        |> Enum.map(fn index ->
          insert(:internal_transaction,
            transaction: tx,
            index: index,
            block_number: tx.block_number,
            transaction_index: tx.index,
            block_hash: tx.block_hash,
            block_index: index
          )
        end)

      request = get(conn, "/api/v2/transactions/#{to_string(tx.hash)}/internal-transactions")
      assert response = json_response(request, 200)

      request_2nd_page =
        get(conn, "/api/v2/transactions/#{to_string(tx.hash)}/internal-transactions", response["next_page_params"])

      assert response_2nd_page = json_response(request_2nd_page, 200)

      check_paginated_response(response, response_2nd_page, internal_txs)
    end
  end

  describe "/transactions/{tx_hash}/logs" do
    test "return empty list on non existing tx", %{conn: conn} do
      tx = build(:transaction)
      request = get(conn, "/api/v2/transactions/#{to_string(tx.hash)}/logs")

      assert response = json_response(request, 200)
      assert response["items"] == []
      assert response["next_page_params"] == nil
    end

    test "return empty list", %{conn: conn} do
      tx =
        :transaction
        |> insert()
        |> with_block()

      request = get(conn, "/api/v2/transactions/#{to_string(tx.hash)}/logs")

      assert response = json_response(request, 200)
      assert response["items"] == []
      assert response["next_page_params"] == nil
    end

    test "return relevant internal transaction", %{conn: conn} do
      tx =
        :transaction
        |> insert()
        |> with_block()

      log =
        insert(:log,
          transaction: tx,
          index: 1,
          block: tx.block,
          block_number: tx.block_number
        )

      tx_1 =
        :transaction
        |> insert()
        |> with_block()

      0..5
      |> Enum.map(fn index ->
        insert(:log,
          transaction: tx_1,
          index: index,
          block: tx_1.block,
          block_number: tx_1.block_number
        )
      end)

      request = get(conn, "/api/v2/transactions/#{to_string(tx.hash)}/logs")

      assert response = json_response(request, 200)
      assert Enum.count(response["items"]) == 1
      assert response["next_page_params"] == nil
      compare_item(log, Enum.at(response["items"], 0))
    end

    test "return internal transaction with next_page_params", %{conn: conn} do
      tx =
        :transaction
        |> insert()
        |> with_block()

      logs =
        50..0
        |> Enum.map(fn index ->
          insert(:log,
            transaction: tx,
            index: index,
            block: tx.block,
            block_number: tx.block_number
          )
        end)

      request = get(conn, "/api/v2/transactions/#{to_string(tx.hash)}/logs")
      assert response = json_response(request, 200)

      request_2nd_page = get(conn, "/api/v2/transactions/#{to_string(tx.hash)}/logs", response["next_page_params"])

      assert response_2nd_page = json_response(request_2nd_page, 200)

      check_paginated_response(response, response_2nd_page, logs)
    end
  end

  defp compare_item(%Transaction{} = transaction, json) do
    assert to_string(transaction.hash) == json["hash"]
    assert transaction.block_number == json["block"]
    # assert to_string(transaction.timestamp) == json["timestamp"]
    assert to_string(transaction.value.value) == json["value"]
  end

  defp compare_item(%InternalTransaction{} = internal_tx, json) do
    assert internal_tx.block_number == json["block"]
    assert to_string(internal_tx.gas) == json["gas_limit"]
    assert internal_tx.index == json["index"]
    assert to_string(internal_tx.transaction_hash) == json["transaction_hash"]
  end

  defp compare_item(%Log{} = log, json) do
    assert to_string(log.data) == json["data"]
    assert log.index == json["index"]
  end

  # [%{"address" => %{"hash" => "0x0000000000000000000000000000000000000005", "implementation_name" => nil, "is_contract" => false, "is_verified" => false, "name" => nil}, "data" => "0x00", "decoded" => nil, "index" => 1, "smart_contract" => nil, "topics" => [nil, nil, nil, nil]}]

  # [%{"block" => 0, "created_contract" => %{"hash" => nil, "implementation_name" => nil, "is_contract" => false, "is_verified" => nil, "name" => nil, "private_tags" => [], "public_tags" => [], "watchlist_names" => []}, "error" => nil, "from" => %{"hash" => "0x0000000000000000000000000000000000000006", "implementation_name" => nil, "is_contract" => false, "is_verified" => false, "name" => nil, "private_tags" => [], "public_tags" => [], "watchlist_names" => []}, "gas_limit" => "78918", "index" => 1, "success" => true, "timestamp" => "2022-11-04T08:30:43.672597Z", "to" => %{"hash" => "0x0000000000000000000000000000000000000007", "implementation_name" => nil, "is_contract" => false, "is_verified" => false, "name" => nil, "private_tags" => [], "public_tags" => [], "watchlist_names" => []}, "transaction_hash" => "0x0000000000000000000000000000000000000000000000000000000000000000", "type" => "delegatecall", "value" => "1"}]

  # %{"base_fee_per_gas" => nil, "block" => 0, "confirmation_duration" => [], "confirmations" => 1, "created_contract" => %{"hash" => nil, "implementation_name" => nil, "is_contract" => false, "is_verified" => nil, "name" => nil, "private_tags" => [], "public_tags" => [], "watchlist_names" => []}, "decoded_input" => nil, "exchange_rate" => nil, "fee" => %{"type" => "actual", "value" => "318163900000000"}, "from" => %{"hash" => "0x0000000000000000000000000000000000000001", "implementation_name" => nil, "is_contract" => false, "is_verified" => nil, "name" => nil, "private_tags" => [], "public_tags" => [], "watchlist_names" => []}, "gas_limit" => "33925", "gas_price" => "8300000000", "gas_used" => "38333", "hash" => "0x0000000000000000000000000000000000000000000000000000000000000000", "max_fee_per_gas" => nil, "max_priority_fee_per_gas" => nil, "method" => nil, "nonce" => 494, "position" => 0, "priority_fee" => nil, "raw_input" => "0x00", "result" => "awaiting_internal_transactions", "revert_reason" => nil, "status" => "error", "timestamp" => "2022-11-03T17:41:27.169732Z", "to" => %{"hash" => "0x0000000000000000000000000000000000000002", "implementation_name" => nil, "is_contract" => false, "is_verified" => false, "name" => nil, "private_tags" => [], "public_tags" => [], "watchlist_names" => []}, "token_transfers" => [], "token_transfers_overflow" => false, "tx_burnt_fee" => nil, "tx_tag" => nil, "tx_types" => ["coin_transfer"], "type" => nil, "value" => "93734"}

  defp check_paginated_response(first_page_resp, second_page_resp, txs) do
    assert Enum.count(first_page_resp["items"]) == 50
    assert first_page_resp["next_page_params"] != nil
    compare_item(Enum.at(txs, 50), Enum.at(first_page_resp["items"], 0))
    compare_item(Enum.at(txs, 1), Enum.at(first_page_resp["items"], 49))

    assert Enum.count(second_page_resp["items"]) == 1
    assert second_page_resp["next_page_params"] == nil
    compare_item(Enum.at(txs, 0), Enum.at(second_page_resp["items"], 0))
  end

  defp debug(value, key) do
    require Logger
    Logger.configure(truncate: :infinity)
    Logger.info(key)
    Logger.info(Kernel.inspect(value, limit: :infinity, printable_limit: :infinity))
    value
  end
end
