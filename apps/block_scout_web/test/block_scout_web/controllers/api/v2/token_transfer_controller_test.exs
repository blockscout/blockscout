defmodule BlockScoutWeb.API.V2.TokenTransferControllerTest do
  use BlockScoutWeb.ConnCase

  alias Explorer.Chain.{Address, TokenTransfer}

  describe "/token-transfers" do
    test "empty list", %{conn: conn} do
      request = get(conn, "/api/v2/token-transfers")

      assert response = json_response(request, 200)
      assert response["items"] == []
      assert response["next_page_params"] == nil
    end

    test "non empty list", %{conn: conn} do
      tx =
        :transaction
        |> insert()
        |> with_block()

      1 |> insert_list(:token_transfer, transaction: tx)

      request = get(conn, "/api/v2/token-transfers")

      assert response = json_response(request, 200)
      assert Enum.count(response["items"]) == 1
      assert response["next_page_params"] == nil
    end

    test "filters by type", %{conn: conn} do
      tx =
        :transaction
        |> insert()
        |> with_block()

      token = insert(:token, type: "ERC-721")

      tt =
        insert(:token_transfer,
          transaction: tx,
          token: token,
          token_type: "ERC-721"
        )

      request = get(conn, "/api/v2/token-transfers?type=ERC-1155")

      assert response = json_response(request, 200)
      assert Enum.count(response["items"]) == 0
      assert response["next_page_params"] == nil
    end

    test "returns all transfers if filter is incorrect", %{conn: conn} do
      tx =
        :transaction
        |> insert()
        |> with_block()

      token = insert(:token, type: "ERC-100500")

      insert(:token_transfer,
        transaction: tx,
        token: token,
        token_type: "ERC-721"
      )

      insert(:token_transfer,
        transaction: tx,
        token: token,
        token_type: "ERC-20"
      )

      request = get(conn, "/api/v2/token-transfers?type=ERC-20")

      assert response = json_response(request, 200)
      assert Enum.count(response["items"]) == 2
      assert response["next_page_params"] == nil
    end

    test "txs with next_page_params", %{conn: conn} do
      token_transfers =
        for _i <- 0..50 do
          tx = insert(:transaction) |> with_block()

          insert(:token_transfer,
            transaction: tx,
            block: tx.block,
            block_number: tx.block_number
          )
        end

      request = get(conn, "/api/v2/token-transfers")
      assert response = json_response(request, 200)

      request_2nd_page = get(conn, "/api/v2/token-transfers", response["next_page_params"])
      assert response_2nd_page = json_response(request_2nd_page, 200)

      check_paginated_response(response, response_2nd_page, token_transfers)
    end
  end

  defp compare_item(%TokenTransfer{} = token_transfer, json) do
    assert Address.checksum(token_transfer.from_address_hash) == json["from"]["hash"]
    assert Address.checksum(token_transfer.to_address_hash) == json["to"]["hash"]
    assert to_string(token_transfer.transaction_hash) == json["transaction_hash"]
    assert token_transfer.transaction.block_timestamp == Timex.parse!(json["block_timestamp"], "{ISO:Extended:Z}")
    assert json["method"] == nil
    assert token_transfer.block_number == json["block_number"]
    assert token_transfer.log_index == json["log_index"]
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
