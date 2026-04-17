defmodule BlockScoutWeb.API.V2.TokenTransferControllerTest do
  use BlockScoutWeb.ConnCase

  alias Explorer.Chain.{Address, TokenTransfer}

  describe "/token-transfers" do
    test "get token-transfers with ok reputation", %{conn: conn} do
      init_value = Application.get_env(:block_scout_web, :hide_scam_addresses)
      Application.put_env(:block_scout_web, :hide_scam_addresses, true)
      on_exit(fn -> Application.put_env(:block_scout_web, :hide_scam_addresses, init_value) end)

      transaction =
        :transaction
        |> insert()
        |> with_block()

      insert(:token_transfer, transaction: transaction)

      request = conn |> put_req_cookie("show_scam_tokens", "true") |> get("/api/v2/token-transfers")
      response = json_response(request, 200)

      assert List.first(response["items"])["token"]["reputation"] == "ok"

      assert response == conn |> get("/api/v2/token-transfers") |> json_response(200)
    end

    test "get smart-contract with scam reputation", %{conn: conn} do
      init_value = Application.get_env(:block_scout_web, :hide_scam_addresses)
      Application.put_env(:block_scout_web, :hide_scam_addresses, true)
      on_exit(fn -> Application.put_env(:block_scout_web, :hide_scam_addresses, init_value) end)

      transaction =
        :transaction
        |> insert()
        |> with_block()

      tt = insert(:token_transfer, transaction: transaction)
      insert(:scam_badge_to_address, address_hash: tt.token_contract_address_hash)

      request = conn |> put_req_cookie("show_scam_tokens", "true") |> get("/api/v2/token-transfers")
      response = json_response(request, 200)

      assert List.first(response["items"])["token"]["reputation"] == "scam"

      request = conn |> get("/api/v2/token-transfers")
      response = json_response(request, 200)

      assert response["items"] == []
    end

    test "get token-transfers with ok reputation with hide_scam_addresses=false", %{conn: conn} do
      init_value = Application.get_env(:block_scout_web, :hide_scam_addresses)
      Application.put_env(:block_scout_web, :hide_scam_addresses, false)
      on_exit(fn -> Application.put_env(:block_scout_web, :hide_scam_addresses, init_value) end)

      transaction =
        :transaction
        |> insert()
        |> with_block()

      insert(:token_transfer, transaction: transaction)

      request = conn |> get("/api/v2/token-transfers")
      response = json_response(request, 200)

      assert List.first(response["items"])["token"]["reputation"] == "ok"
    end

    test "get token-transfers with scam reputation with hide_scam_addresses=false", %{conn: conn} do
      init_value = Application.get_env(:block_scout_web, :hide_scam_addresses)
      Application.put_env(:block_scout_web, :hide_scam_addresses, false)
      on_exit(fn -> Application.put_env(:block_scout_web, :hide_scam_addresses, init_value) end)

      transaction =
        :transaction
        |> insert()
        |> with_block()

      tt = insert(:token_transfer, transaction: transaction)
      insert(:scam_badge_to_address, address_hash: tt.token_contract_address_hash)

      request = conn |> get("/api/v2/token-transfers")
      response = json_response(request, 200)

      assert List.first(response["items"])["token"]["reputation"] == "ok"
    end

    test "empty list", %{conn: conn} do
      request = get(conn, "/api/v2/token-transfers")

      assert response = json_response(request, 200)
      assert response["items"] == []
      assert response["next_page_params"] == nil
    end

    test "non empty list", %{conn: conn} do
      transaction =
        :transaction
        |> insert()
        |> with_block()

      1 |> insert_list(:token_transfer, transaction: transaction)

      request = get(conn, "/api/v2/token-transfers")

      assert response = json_response(request, 200)
      assert Enum.count(response["items"]) == 1
      assert response["next_page_params"] == nil
    end

    test "filters by type", %{conn: conn} do
      transaction =
        :transaction
        |> insert()
        |> with_block()

      token = insert(:token, type: "ERC-721")

      insert(:token_transfer,
        transaction: transaction,
        token: token,
        token_type: "ERC-721"
      )

      request = get(conn, "/api/v2/token-transfers?type=ERC-1155")

      assert response = json_response(request, 200)
      assert Enum.count(response["items"]) == 0
      assert response["next_page_params"] == nil
    end

    test "filters by ERC-7984 type", %{conn: conn} do
      transaction =
        :transaction
        |> insert()
        |> with_block()

      erc7984_token = insert(:token, type: "ERC-7984")

      insert(:token_transfer,
        transaction: transaction,
        token: erc7984_token,
        token_contract_address: erc7984_token.contract_address,
        token_type: "ERC-7984",
        amount: nil
      )

      erc20_token = insert(:token, type: "ERC-20")

      insert(:token_transfer,
        transaction: transaction,
        token: erc20_token,
        token_contract_address: erc20_token.contract_address,
        token_type: "ERC-20"
      )

      request = get(conn, "/api/v2/token-transfers?type=ERC-7984")

      assert response = json_response(request, 200)
      assert Enum.count(response["items"]) == 1
      assert response["next_page_params"] == nil
      assert List.first(response["items"])["token_type"] == "ERC-7984"
    end

    test "returns all transfers if filter is incorrect", %{conn: conn} do
      transaction =
        :transaction
        |> insert()
        |> with_block()

      token = insert(:token, type: "ERC-100500")

      insert(:token_transfer,
        transaction: transaction,
        token: token,
        token_type: "ERC-721",
        token_ids: [1]
      )

      insert(:token_transfer,
        transaction: transaction,
        token: token,
        token_type: "ERC-20"
      )

      request = get(conn, "/api/v2/token-transfers?type=ERC-20")

      assert response = json_response(request, 200)
      assert Enum.count(response["items"]) == 2
      assert response["next_page_params"] == nil
    end

    test "token transfers with next_page_params", %{conn: conn} do
      token_transfers =
        for _i <- 0..50 do
          transaction = insert(:transaction) |> with_block()

          insert(:token_transfer,
            transaction: transaction,
            block: transaction.block,
            block_number: transaction.block_number
          )
        end

      request = get(conn, "/api/v2/token-transfers")
      assert response = json_response(request, 200)

      request_2nd_page = get(conn, "/api/v2/token-transfers", response["next_page_params"])
      assert response_2nd_page = json_response(request_2nd_page, 200)

      check_paginated_response(response, response_2nd_page, nil, token_transfers)
    end

    test "flatten erc1155 batch token transfer", %{conn: conn} do
      transaction = insert(:transaction) |> with_block()

      transfer =
        insert(:token_transfer,
          transaction: transaction,
          block: transaction.block,
          block_number: transaction.block_number,
          token_ids: [1, 2, 3],
          amounts: [500, 600, 700],
          token_type: "ERC-1155"
        )

      insert(:token_instance,
        token_id: 3,
        token_contract_address_hash: transfer.token_contract_address_hash,
        metadata: %{test: "test"}
      )

      request = get(conn, "/api/v2/token-transfers")
      assert response = json_response(request, 200)
      assert Enum.count(response["items"]) == 3

      assert %{"decimals" => "18", "value" => "700", "token_id" => "3", "token_instance" => token_instance} =
               Enum.at(response["items"], 0)["total"]

      assert token_instance["metadata"] == %{"test" => "test"}
    end

    test "paginates erc1155 batch token transfers", %{conn: conn} do
      token_transfers =
        for _i <- 0..50 do
          transaction = insert(:transaction) |> with_block()

          insert(:token_transfer,
            transaction: transaction,
            block: transaction.block,
            block_number: transaction.block_number,
            token_ids: [1, 2],
            amounts: [500, 600],
            token_type: "ERC-1155"
          )
        end

      request = get(conn, "/api/v2/token-transfers")
      assert response = json_response(request, 200)

      request_2nd_page = get(conn, "/api/v2/token-transfers", response["next_page_params"])
      assert response_2nd_page = json_response(request_2nd_page, 200)

      request_3d_page = get(conn, "/api/v2/token-transfers", response_2nd_page["next_page_params"])
      assert response_3d_page = json_response(request_3d_page, 200)

      check_paginated_response(response, response_2nd_page, response_3d_page, token_transfers)
    end
  end

  defp compare_item(%TokenTransfer{} = token_transfer, json) do
    assert Address.checksum(token_transfer.from_address_hash) == json["from"]["hash"]
    assert Address.checksum(token_transfer.to_address_hash) == json["to"]["hash"]
    assert to_string(token_transfer.transaction_hash) == json["transaction_hash"]
    assert token_transfer.transaction.block_timestamp == Timex.parse!(json["timestamp"], "{ISO:Extended:Z}")
    assert json["method"] == nil
    assert token_transfer.block_number == json["block_number"]
    assert token_transfer.log_index == json["log_index"]
  end

  defp check_paginated_response(first_page_resp, second_page_resp, third_page_resp, token_transfers) do
    assert Enum.count(first_page_resp["items"]) == 50
    assert first_page_resp["next_page_params"] != nil
    compare_item(Enum.at(token_transfers, 50), Enum.at(first_page_resp["items"], 0))

    if is_nil(third_page_resp) do
      compare_item(Enum.at(token_transfers, 1), Enum.at(first_page_resp["items"], 49))

      assert Enum.count(second_page_resp["items"]) == 1
      assert second_page_resp["next_page_params"] == nil
      compare_item(Enum.at(token_transfers, 0), Enum.at(second_page_resp["items"], 0))
    else
      assert Enum.count(second_page_resp["items"]) == 50
      assert second_page_resp["next_page_params"] !== nil

      compare_item(Enum.at(token_transfers, 1), Enum.at(second_page_resp["items"], 49))

      assert Enum.count(third_page_resp["items"]) == 2
      assert third_page_resp["next_page_params"] == nil
      compare_item(Enum.at(token_transfers, 0), Enum.at(third_page_resp["items"], 0))
    end
  end
end
