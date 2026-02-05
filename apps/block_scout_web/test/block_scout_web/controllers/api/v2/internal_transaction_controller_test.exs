defmodule BlockScoutWeb.API.V2.InternalTransactionControllerTest do
  use BlockScoutWeb.ConnCase

  alias Explorer.Chain.{Address, InternalTransaction}
  alias Explorer.Chain.Cache.BackgroundMigrations

  describe "/internal-transactions" do
    setup do
      BackgroundMigrations.set_heavy_indexes_create_internal_transactions_block_number_desc_transaction_index_desc_index_desc_index_finished(
        true
      )

      :ok
    end

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
        transaction_index: 0,
        block_number: tx.block_number,
        block_hash: tx.block_hash,
        index: 1
      )

      request = get(conn, "/api/v2/internal-transactions")

      assert response = json_response(request, 200)
      assert Enum.count(response["items"]) == 1
      assert response["next_page_params"] == nil
    end

    test "internal transactions with next_page_params", %{conn: conn} do
      transaction = insert(:transaction) |> with_block()

      internal_transaction =
        insert(:internal_transaction,
          transaction: transaction,
          transaction_index: 0,
          block_number: transaction.block_number,
          block_hash: transaction.block_hash,
          index: 1
        )

      transaction_2 = insert(:transaction) |> with_block()

      internal_transactions =
        for i <- 1..50 do
          insert(:internal_transaction,
            transaction: transaction_2,
            transaction_index: 0,
            block_number: transaction_2.block_number,
            block_hash: transaction_2.block_hash,
            index: i
          )
        end

      internal_transactions = [internal_transaction | internal_transactions]

      request = get(conn, "/api/v2/internal-transactions")
      assert response = json_response(request, 200)

      request_2nd_page = get(conn, "/api/v2/internal-transactions", response["next_page_params"])
      assert response_2nd_page = json_response(request_2nd_page, 200)

      check_paginated_response(response, response_2nd_page, internal_transactions)
    end

    test "excludes zero index internal transaction when querying by transaction_hash", %{conn: conn} do
      tx =
        :transaction
        |> insert()
        |> with_block()

      # Insert internal transaction with index 0 (origin sender transaction) - should be excluded
      insert(:internal_transaction,
        transaction: tx,
        transaction_index: 0,
        block_number: tx.block_number,
        block_hash: tx.block_hash,
        index: 0,
        type: :call
      )

      # Insert internal transaction with index 1 - should be included
      _it_1 =
        insert(:internal_transaction,
          transaction: tx,
          transaction_index: 0,
          block_number: tx.block_number,
          block_hash: tx.block_hash,
          index: 1,
          type: :call
        )

      # Insert internal transaction with index 2 - should be included
      _it_2 =
        insert(:internal_transaction,
          transaction: tx,
          transaction_index: 0,
          block_number: tx.block_number,
          block_hash: tx.block_hash,
          index: 2,
          type: :call
        )

      request = get(conn, "/api/v2/internal-transactions", %{"transaction_hash" => to_string(tx.hash)})

      assert response = json_response(request, 200)
      assert Enum.count(response["items"]) == 2
      assert response["next_page_params"] == nil

      # Verify that only index 1 and 2 are returned, not index 0
      returned_indices = Enum.map(response["items"], & &1["index"])
      assert 1 in returned_indices
      assert 2 in returned_indices
      refute 0 in returned_indices
    end

    test "pagination works correctly with zero index filtering", %{conn: conn} do
      tx =
        :transaction
        |> insert()
        |> with_block()

      # Insert internal transaction with index 0 - should be excluded
      insert(:internal_transaction,
        transaction: tx,
        transaction_index: 0,
        block_number: tx.block_number,
        block_hash: tx.block_hash,
        index: 0,
        type: :call
      )

      # Insert 51 internal transactions with index 1-51
      for i <- 1..51 do
        insert(:internal_transaction,
          transaction: tx,
          transaction_index: 0,
          block_number: tx.block_number,
          block_hash: tx.block_hash,
          index: i,
          type: :call
        )
      end

      request = get(conn, "/api/v2/internal-transactions", %{"transaction_hash" => to_string(tx.hash)})
      assert response = json_response(request, 200)

      # Should return 50 items (excluding index 0)
      assert Enum.count(response["items"]) == 50
      assert response["next_page_params"] != nil

      # First item should be index 1, not 0
      assert List.first(response["items"])["index"] == 1

      # Get second page
      request_2nd_page = get(conn, "/api/v2/internal-transactions", response["next_page_params"])
      assert response_2nd_page = json_response(request_2nd_page, 200)

      # Second page should have 1 item
      assert Enum.count(response_2nd_page["items"]) == 1
      assert response_2nd_page["next_page_params"] == nil
    end
  end

  defp compare_item(%InternalTransaction{} = internal_transaction, json) do
    assert Address.checksum(internal_transaction.from_address_hash) == json["from"]["hash"]
    assert Address.checksum(internal_transaction.to_address_hash) == json["to"]["hash"]
    assert to_string(internal_transaction.transaction_hash) == json["transaction_hash"]
    assert internal_transaction.block_number == json["block_number"]
    assert internal_transaction.transaction_index == json["transaction_index"]
    assert internal_transaction.index == json["index"]
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
