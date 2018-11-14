defmodule BlockScoutWeb.TransactionControllerTest do
  use BlockScoutWeb.ConnCase
  alias Explorer.Chain.{Block, Transaction}

  import BlockScoutWeb.Router.Helpers,
    only: [transaction_path: 3, transaction_internal_transaction_path: 3, transaction_token_transfer_path: 3]

  describe "GET index/2" do
    test "returns a collated transactions", %{conn: conn} do
      transaction =
        :transaction
        |> insert()
        |> with_block()

      conn = get(conn, "/txs")

      assert List.first(conn.assigns.transactions).hash == transaction.hash
    end

    test "returns a count of transactions", %{conn: conn} do
      :transaction
      |> insert()
      |> with_block()

      conn = get(conn, "/txs")

      assert is_integer(conn.assigns.transaction_estimated_count)
    end

    test "excludes pending transactions", %{conn: conn} do
      %Transaction{hash: hash} =
        :transaction
        |> insert()
        |> with_block()

      insert(:transaction)

      conn = get(conn, "/txs")

      assert [%Transaction{hash: ^hash}] = conn.assigns.transactions
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
        get(conn, "/txs", %{
          "type" => "JSON",
          "block_number" => Integer.to_string(block_number),
          "index" => Integer.to_string(index)
        })

      {:ok, %{"transactions" => transactions}} = conn.resp_body |> Poison.decode()

      actual_hashes =
        transactions
        |> Enum.map(& &1["transaction_hash"])
        |> Enum.reverse()

      assert second_page_hashes == actual_hashes
    end

    test "next_page_params exist if not on last page", %{conn: conn} do
      address = insert(:address)
      block = %Block{number: number} = insert(:block)

      60
      |> insert_list(:transaction, from_address: address)
      |> with_block(block)

      conn = get(conn, "/txs")

      assert %{"block_number" => ^number, "index" => 10} = conn.assigns.next_page_params
    end

    test "next_page_params are empty if on last page", %{conn: conn} do
      address = insert(:address)

      :transaction
      |> insert(from_address: address)
      |> with_block()

      conn = get(conn, "/txs")

      refute conn.assigns.next_page_params
    end

    test "works when there are no transactions", %{conn: conn} do
      conn = get(conn, "/txs")

      assert conn.assigns.transactions == []
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

    test "redirects to transactions/:transaction_id/token_transfers when there are token transfers", %{conn: conn} do
      transaction = insert(:transaction)
      insert(:token_transfer, transaction: transaction)
      conn = get(conn, transaction_path(BlockScoutWeb.Endpoint, :show, transaction))

      assert redirected_to(conn) =~ transaction_token_transfer_path(BlockScoutWeb.Endpoint, :index, transaction)
    end

    test "redirects to transactions/:transaction_id/internal_transactions when there are no token transfers", %{
      conn: conn
    } do
      transaction = insert(:transaction)
      conn = get(conn, transaction_path(BlockScoutWeb.Endpoint, :show, transaction))

      assert redirected_to(conn) =~ transaction_internal_transaction_path(BlockScoutWeb.Endpoint, :index, transaction)
    end
  end
end
