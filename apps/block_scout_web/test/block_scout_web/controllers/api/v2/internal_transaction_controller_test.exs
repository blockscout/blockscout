defmodule BlockScoutWeb.API.V2.InternalTransactionControllerTest do
  use BlockScoutWeb.ConnCase

  alias Explorer.Chain.{Address, InternalTransaction}

  describe "/internal-transactions" do
    test "empty list", %{conn: conn} do
      request = get(conn, "/api/v2/internal-transactions")

      assert response = json_response(request, 200)
      assert response["items"] == []
      assert response["next_page_params"] == nil
    end

    test "non empty list", %{conn: conn} do
      tx =
        :transaction
        |> insert()
        |> with_block()

      insert(:internal_transaction,
        transaction: tx,
        block_hash: tx.block_hash,
        index: 0,
        block_index: 0
      )

      request = get(conn, "/api/v2/internal-transactions")

      assert response = json_response(request, 200)
      assert Enum.count(response["items"]) == 1
      assert response["next_page_params"] == nil
    end

    test "internal transactions with next_page_params", %{conn: conn} do
      internal_transactions =
        for i <- 0..50 do
          tx = insert(:transaction) |> with_block()

          insert(:internal_transaction,
            transaction: tx,
            block_number: tx.block_number,
            block_hash: tx.block_hash,
            index: i,
            block_index: i
          )
        end

      request = get(conn, "/api/v2/internal-transactions")
      assert response = json_response(request, 200)

      request_2nd_page = get(conn, "/api/v2/internal-transactions", response["next_page_params"])
      assert response_2nd_page = json_response(request_2nd_page, 200)

      check_paginated_response(response, response_2nd_page, internal_transactions)
    end
  end

  defp compare_item(%InternalTransaction{} = internal_transaction, json) do
    assert Address.checksum(internal_transaction.from_address_hash) == json["from"]["hash"]
    assert Address.checksum(internal_transaction.to_address_hash) == json["to"]["hash"]
    assert to_string(internal_transaction.transaction_hash) == json["transaction_hash"]
    assert internal_transaction.block_number == json["block_number"]
    assert internal_transaction.block_index == json["block_index"]
  end

  defp check_paginated_response(first_page_resp, second_page_resp, internal_transactions) do
    assert Enum.count(first_page_resp["items"]) == 50
    assert first_page_resp["next_page_params"] != nil
    compare_item(Enum.at(internal_transactions, 50), Enum.at(first_page_resp["items"], 0))

    compare_item(Enum.at(internal_transactions, 1), Enum.at(first_page_resp["items"], 49))

    assert Enum.count(second_page_resp["items"]) == 1
    assert second_page_resp["next_page_params"] == nil
    compare_item(Enum.at(internal_transactions, 0), Enum.at(second_page_resp["items"], 0))
  end
end