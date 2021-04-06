defmodule BlockScoutWeb.TransactionControllerTest do
  use BlockScoutWeb.ConnCase

  import BlockScoutWeb.WebRouter.Helpers,
    only: [transaction_path: 3, transaction_internal_transaction_path: 3, transaction_token_transfer_path: 3]

  alias Explorer.Chain.Transaction

  describe "GET index/2" do
    test "returns a collated transactions", %{conn: conn} do
      :transaction
      |> insert()
      |> with_block()

      conn = get(conn, transaction_path(conn, :index, %{"type" => "JSON"}))

      transactions_html =
        conn
        |> json_response(200)
        |> Map.get("items")

      assert length(transactions_html) == 1
    end

    test "returns a count of transactions", %{conn: conn} do
      :transaction
      |> insert()
      |> with_block()

      conn = get(conn, "/txs")

      assert is_integer(conn.assigns.transaction_estimated_count)
    end

    test "excludes pending transactions", %{conn: conn} do
      %Transaction{hash: transaction_hash} =
        :transaction
        |> insert()
        |> with_block()

      %Transaction{hash: pending_transaction_hash} = insert(:transaction)

      conn = get(conn, transaction_path(conn, :index, %{"type" => "JSON"}))

      transactions_html =
        conn
        |> json_response(200)
        |> Map.get("items")

      assert Enum.any?(transactions_html, &String.contains?(&1, to_string(transaction_hash)))
      refute Enum.any?(transactions_html, &String.contains?(&1, to_string(pending_transaction_hash)))
    end

    test "returns next page of results based on last seen transaction", %{conn: conn} do
      second_page_hashes =
        50
        |> insert_list(:transaction)
        |> with_block()
        |> Enum.map(&to_string(&1.hash))

      %Transaction{block_number: block_number, index: index} =
        :transaction
        |> insert()
        |> with_block()

      conn =
        get(
          conn,
          transaction_path(conn, :index, %{
            "type" => "JSON",
            "block_number" => Integer.to_string(block_number),
            "index" => Integer.to_string(index)
          })
        )

      transactions_html =
        conn
        |> json_response(200)
        |> Map.get("items")

      assert length(second_page_hashes) == length(transactions_html)
    end

    test "next_page_params exist if not on last page", %{conn: conn} do
      address = insert(:address)
      block = insert(:block)

      60
      |> insert_list(:transaction, from_address: address)
      |> with_block(block)

      conn = get(conn, transaction_path(conn, :index, %{"type" => "JSON"}))

      assert conn |> json_response(200) |> Map.get("next_page_path")
    end

    test "next_page_params are empty if on last page", %{conn: conn} do
      address = insert(:address)

      :transaction
      |> insert(from_address: address)
      |> with_block()

      conn = get(conn, transaction_path(conn, :index, %{"type" => "JSON"}))

      refute conn |> json_response(200) |> Map.get("next_page_path")
    end

    test "works when there are no transactions", %{conn: conn} do
      conn = get(conn, "/txs")

      assert html_response(conn, 200)
    end
  end

  describe "GET show/3" do
    test "responds with 404 with the transaction missing", %{conn: conn} do
      hash = transaction_hash()
      conn = get(conn, transaction_path(BlockScoutWeb.Endpoint, :show, hash))

      assert html_response(conn, 404)
    end

    test "responds with 422 when the hash is invalid", %{conn: conn} do
      conn = get(conn, transaction_path(BlockScoutWeb.Endpoint, :show, "wrong"))

      assert html_response(conn, 422)
    end
  end
end
