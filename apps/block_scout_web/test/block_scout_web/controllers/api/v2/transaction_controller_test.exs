defmodule BlockScoutWeb.API.V2.TransactionControllerTest do
  use BlockScoutWeb.ConnCase

  alias Explorer.Chain.{Address, InternalTransaction, Log, TokenTransfer, Transaction}

  setup do
    Supervisor.terminate_child(Explorer.Supervisor, Explorer.Chain.Cache.TransactionsApiV2.child_id())
    Supervisor.restart_child(Explorer.Supervisor, Explorer.Chain.Cache.TransactionsApiV2.child_id())

    :ok
  end

  describe "/transactions" do
    test "empty list", %{conn: conn} do
      request = get(conn, "/api/v2/transactions")

      assert response = json_response(request, 200)
      assert response["items"] == []
      assert response["next_page_params"] == nil
    end

    test "non empty list", %{conn: conn} do
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

      filter = %{"filter" => "pending"}

      request = get(conn, "/api/v2/transactions", filter)
      assert response = json_response(request, 200)

      request_2nd_page = get(conn, "/api/v2/transactions", Map.merge(response["next_page_params"], filter))
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

      filter = %{"filter" => "validated"}

      request = get(conn, "/api/v2/transactions", filter)
      assert response = json_response(request, 200)

      request_2nd_page = get(conn, "/api/v2/transactions", Map.merge(response["next_page_params"], filter))
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
    test "return 404 on non existing tx", %{conn: conn} do
      tx = build(:transaction)
      request = get(conn, "/api/v2/transactions/#{to_string(tx.hash)}/internal-transactions")

      assert %{"message" => "Not found"} = json_response(request, 404)
    end

    test "return 422 on invalid tx hash", %{conn: conn} do
      request = get(conn, "/api/v2/transactions/0x/internal-transactions")

      assert %{"message" => "Invalid parameter(s)"} = json_response(request, 422)
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

    test "return list with next_page_params", %{conn: conn} do
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
    test "return 404 on non existing tx", %{conn: conn} do
      tx = build(:transaction)
      request = get(conn, "/api/v2/transactions/#{to_string(tx.hash)}/logs")

      assert %{"message" => "Not found"} = json_response(request, 404)
    end

    test "return 422 on invalid tx hash", %{conn: conn} do
      request = get(conn, "/api/v2/transactions/0x/logs")

      assert %{"message" => "Invalid parameter(s)"} = json_response(request, 422)
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

    test "return relevant log", %{conn: conn} do
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

    test "return list with next_page_params", %{conn: conn} do
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

  describe "/transactions/{tx_hash}/token-transfers" do
    test "return 404 on non existing tx", %{conn: conn} do
      tx = build(:transaction)
      request = get(conn, "/api/v2/transactions/#{to_string(tx.hash)}/token-transfers")

      assert %{"message" => "Not found"} = json_response(request, 404)
    end

    test "return 422 on invalid tx hash", %{conn: conn} do
      request = get(conn, "/api/v2/transactions/0x/token-transfers")

      assert %{"message" => "Invalid parameter(s)"} = json_response(request, 422)
    end

    test "return empty list", %{conn: conn} do
      tx =
        :transaction
        |> insert()
        |> with_block()

      request = get(conn, "/api/v2/transactions/#{to_string(tx.hash)}/token-transfers")

      assert response = json_response(request, 200)
      assert response["items"] == []
      assert response["next_page_params"] == nil
    end

    test "return relevant token transfer", %{conn: conn} do
      tx =
        :transaction
        |> insert()
        |> with_block()

      token_transfer = insert(:token_transfer, transaction: tx, block: tx.block, block_number: tx.block_number)

      tx_1 =
        :transaction
        |> insert()
        |> with_block()

      insert_list(6, :token_transfer, transaction: tx_1, block: tx_1.block, block_number: tx_1.block_number)

      request = get(conn, "/api/v2/transactions/#{to_string(tx.hash)}/token-transfers")

      assert response = json_response(request, 200)
      assert Enum.count(response["items"]) == 1
      assert response["next_page_params"] == nil
      compare_item(token_transfer, Enum.at(response["items"], 0))
    end

    test "return list with next_page_params", %{conn: conn} do
      tx =
        :transaction
        |> insert()
        |> with_block()

      token_transfers =
        insert_list(51, :token_transfer, transaction: tx, block: tx.block, block_number: tx.block_number)
        |> Enum.reverse()

      request = get(conn, "/api/v2/transactions/#{to_string(tx.hash)}/token-transfers")
      assert response = json_response(request, 200)

      request_2nd_page =
        get(conn, "/api/v2/transactions/#{to_string(tx.hash)}/token-transfers", response["next_page_params"])

      assert response_2nd_page = json_response(request_2nd_page, 200)

      check_paginated_response(response, response_2nd_page, token_transfers)
    end

    test "check filters", %{conn: conn} do
      tx =
        :transaction
        |> insert()
        |> with_block()

      erc_1155_token = insert(:token, type: "ERC-1155")

      erc_1155_tt =
        for x <- 0..50 do
          insert(:token_transfer,
            transaction: tx,
            block: tx.block,
            block_number: tx.block_number,
            token_contract_address: erc_1155_token.contract_address,
            token_ids: [x]
          )
        end
        |> Enum.reverse()

      erc_721_token = insert(:token, type: "ERC-721")

      erc_721_tt =
        for x <- 0..50 do
          insert(:token_transfer,
            transaction: tx,
            block: tx.block,
            block_number: tx.block_number,
            token_contract_address: erc_721_token.contract_address,
            token_ids: [x]
          )
        end
        |> Enum.reverse()

      erc_20_token = insert(:token, type: "ERC-20")

      erc_20_tt =
        for _ <- 0..50 do
          insert(:token_transfer,
            transaction: tx,
            block: tx.block,
            block_number: tx.block_number,
            token_contract_address: erc_20_token.contract_address
          )
        end
        |> Enum.reverse()

      # -- ERC-20 --
      filter = %{"type" => "ERC-20"}
      request = get(conn, "/api/v2/transactions/#{to_string(tx.hash)}/token-transfers", filter)
      assert response = json_response(request, 200)

      request_2nd_page =
        get(
          conn,
          "/api/v2/transactions/#{to_string(tx.hash)}/token-transfers",
          Map.merge(response["next_page_params"], filter)
        )

      assert response_2nd_page = json_response(request_2nd_page, 200)

      check_paginated_response(response, response_2nd_page, erc_20_tt)
      # -- ------ --

      # -- ERC-721 --
      filter = %{"type" => "ERC-721"}
      request = get(conn, "/api/v2/transactions/#{to_string(tx.hash)}/token-transfers", filter)
      assert response = json_response(request, 200)

      request_2nd_page =
        get(
          conn,
          "/api/v2/transactions/#{to_string(tx.hash)}/token-transfers",
          Map.merge(response["next_page_params"], filter)
        )

      assert response_2nd_page = json_response(request_2nd_page, 200)

      check_paginated_response(response, response_2nd_page, erc_721_tt)
      # -- ------ --

      # -- ERC-1155 --
      filter = %{"type" => "ERC-1155"}
      request = get(conn, "/api/v2/transactions/#{to_string(tx.hash)}/token-transfers", filter)
      assert response = json_response(request, 200)

      request_2nd_page =
        get(
          conn,
          "/api/v2/transactions/#{to_string(tx.hash)}/token-transfers",
          Map.merge(response["next_page_params"], filter)
        )

      assert response_2nd_page = json_response(request_2nd_page, 200)

      check_paginated_response(response, response_2nd_page, erc_1155_tt)
      # -- ------ --

      # two filters simultaneously
      filter = %{"type" => "ERC-1155,ERC-20"}
      request = get(conn, "/api/v2/transactions/#{to_string(tx.hash)}/token-transfers", filter)
      assert response = json_response(request, 200)

      request_2nd_page =
        get(
          conn,
          "/api/v2/transactions/#{to_string(tx.hash)}/token-transfers",
          Map.merge(response["next_page_params"], filter)
        )

      assert response_2nd_page = json_response(request_2nd_page, 200)

      assert Enum.count(response["items"]) == 50
      assert response["next_page_params"] != nil
      compare_item(Enum.at(erc_1155_tt, 50), Enum.at(response["items"], 0))
      compare_item(Enum.at(erc_1155_tt, 1), Enum.at(response["items"], 49))

      assert Enum.count(response_2nd_page["items"]) == 50
      assert response_2nd_page["next_page_params"] != nil
      compare_item(Enum.at(erc_1155_tt, 0), Enum.at(response_2nd_page["items"], 0))
      compare_item(Enum.at(erc_20_tt, 50), Enum.at(response_2nd_page["items"], 1))
      compare_item(Enum.at(erc_20_tt, 2), Enum.at(response_2nd_page["items"], 49))

      request_3rd_page =
        get(
          conn,
          "/api/v2/transactions/#{to_string(tx.hash)}/token-transfers",
          Map.merge(response_2nd_page["next_page_params"], filter)
        )

      assert response_3rd_page = json_response(request_3rd_page, 200)
      assert Enum.count(response_3rd_page["items"]) == 2
      assert response_3rd_page["next_page_params"] == nil
      compare_item(Enum.at(erc_20_tt, 1), Enum.at(response_3rd_page["items"], 0))
      compare_item(Enum.at(erc_20_tt, 0), Enum.at(response_3rd_page["items"], 1))
    end
  end

  defp compare_item(%Transaction{} = transaction, json) do
    assert to_string(transaction.hash) == json["hash"]
    assert transaction.block_number == json["block"]
    assert to_string(transaction.value.value) == json["value"]
    assert Address.checksum(transaction.from_address_hash) == json["from"]["hash"]
    assert Address.checksum(transaction.to_address_hash) == json["to"]["hash"]
  end

  defp compare_item(%InternalTransaction{} = internal_tx, json) do
    assert internal_tx.block_number == json["block"]
    assert to_string(internal_tx.gas) == json["gas_limit"]
    assert internal_tx.index == json["index"]
    assert to_string(internal_tx.transaction_hash) == json["transaction_hash"]
    assert Address.checksum(internal_tx.from_address_hash) == json["from"]["hash"]
    assert Address.checksum(internal_tx.to_address_hash) == json["to"]["hash"]
  end

  defp compare_item(%Log{} = log, json) do
    assert to_string(log.data) == json["data"]
    assert log.index == json["index"]
    assert Address.checksum(log.address_hash) == json["address"]["hash"]
    assert to_string(log.transaction_hash) == json["tx_hash"]
  end

  defp compare_item(%TokenTransfer{} = token_transfer, json) do
    assert Address.checksum(token_transfer.from_address_hash) == json["from"]["hash"]
    assert Address.checksum(token_transfer.to_address_hash) == json["to"]["hash"]
    assert to_string(token_transfer.transaction_hash) == json["tx_hash"]
  end

  defp check_paginated_response(first_page_resp, second_page_resp, txs) do
    assert Enum.count(first_page_resp["items"]) == 50
    assert first_page_resp["next_page_params"] != nil
    compare_item(Enum.at(txs, 50), Enum.at(first_page_resp["items"], 0))
    compare_item(Enum.at(txs, 1), Enum.at(first_page_resp["items"], 49))

    assert Enum.count(second_page_resp["items"]) == 1
    assert second_page_resp["next_page_params"] == nil
    compare_item(Enum.at(txs, 0), Enum.at(second_page_resp["items"], 0))
  end
end
