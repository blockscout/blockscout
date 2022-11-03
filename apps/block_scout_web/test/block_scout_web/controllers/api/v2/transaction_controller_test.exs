defmodule BlockScoutWeb.API.V2.TransactionControllerTest do
  use BlockScoutWeb.ConnCase

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
      request = get(conn, "/api/v2/transactions/0xe38c6772f33edfbd218f59853befe18391cb786f911fb6c0b00ed6dd72ef6e69")

      assert %{"message" => "Not found"} = json_response(request, 404)
    end

    test "return existing tx", %{conn: conn} do
      tx =
        :transaction
        |> insert()
        |> with_block()

      request = get(conn, "/api/v2/transactions/" <> to_string(tx.hash))

      assert response = json_response(request, 200)
      debug(response, "123123123123")
      compare_tx(tx, response)
    end
  end

  defp compare_tx(transaction, json) do
    assert to_string(transaction.hash) == json["hash"]
    assert transaction.block_number == json["block"]
    # assert to_string(transaction.timestamp) == json["timestamp"]
    assert to_string(transaction.value.value) == json["value"]
  end

  # %{"base_fee_per_gas" => nil, "block" => 0, "confirmation_duration" => [], "confirmations" => 1, "created_contract" => %{"hash" => nil, "implementation_name" => nil, "is_contract" => false, "is_verified" => nil, "name" => nil, "private_tags" => [], "public_tags" => [], "watchlist_names" => []}, "decoded_input" => nil, "exchange_rate" => nil, "fee" => %{"type" => "actual", "value" => "318163900000000"}, "from" => %{"hash" => "0x0000000000000000000000000000000000000001", "implementation_name" => nil, "is_contract" => false, "is_verified" => nil, "name" => nil, "private_tags" => [], "public_tags" => [], "watchlist_names" => []}, "gas_limit" => "33925", "gas_price" => "8300000000", "gas_used" => "38333", "hash" => "0x0000000000000000000000000000000000000000000000000000000000000000", "max_fee_per_gas" => nil, "max_priority_fee_per_gas" => nil, "method" => nil, "nonce" => 494, "position" => 0, "priority_fee" => nil, "raw_input" => "0x00", "result" => "awaiting_internal_transactions", "revert_reason" => nil, "status" => "error", "timestamp" => "2022-11-03T17:41:27.169732Z", "to" => %{"hash" => "0x0000000000000000000000000000000000000002", "implementation_name" => nil, "is_contract" => false, "is_verified" => false, "name" => nil, "private_tags" => [], "public_tags" => [], "watchlist_names" => []}, "token_transfers" => [], "token_transfers_overflow" => false, "tx_burnt_fee" => nil, "tx_tag" => nil, "tx_types" => ["coin_transfer"], "type" => nil, "value" => "93734"}

  defp check_paginated_response(first_page_resp, second_page_resp, txs) do
    assert Enum.count(first_page_resp["items"]) == 50
    assert first_page_resp["next_page_params"] != nil
    compare_tx(Enum.at(txs, 50), Enum.at(first_page_resp["items"], 0))
    compare_tx(Enum.at(txs, 1), Enum.at(first_page_resp["items"], 49))

    assert Enum.count(second_page_resp["items"]) == 1
    assert second_page_resp["next_page_params"] == nil
    compare_tx(Enum.at(txs, 0), Enum.at(second_page_resp["items"], 0))
  end

  defp debug(value, key) do
    require Logger
    Logger.configure(truncate: :infinity)
    Logger.info(key)
    Logger.info(Kernel.inspect(value, limit: :infinity, printable_limit: :infinity))
    value
  end
end
