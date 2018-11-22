defmodule BlockScoutWeb.TransactionControllerTest do
  use BlockScoutWeb.ConnCase
  alias Explorer.Chain.Transaction

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

    test "returns second page of transactions", %{conn: conn} do
      address = insert(:address)
      block = insert(:block)

      second_page_txs =
        10
        |> insert_list(:transaction, from_address: address)
        |> with_block(block)

      _first_page_txs =
        50
        |> insert_list(:transaction, from_address: address)
        |> with_block(block)

      conn = get(conn, "/txs?p=2")

      assert Enum.count(conn.assigns.transactions) == 10
      assert List.first(conn.assigns.transactions).hash == List.last(second_page_txs).hash
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

    test "next_page_params exist if not on last page", %{conn: conn} do
      address = insert(:address)
      block = insert(:block)

      60
      |> insert_list(:transaction, from_address: address)
      |> with_block(block)

      conn = get(conn, "/txs")

      assert %{"p" => "2"} = conn.assigns.next_page_params
    end

    test "prev_page_params exist if not on first page", %{conn: conn} do
      address = insert(:address)
      block = insert(:block)

      60
      |> insert_list(:transaction, from_address: address)
      |> with_block(block)

      conn = get(conn, "/txs?p=2")

      assert %{"p" => "1"} = conn.assigns.prev_page_params
    end

    test "prev_page_params are empty if on first page", %{conn: conn} do
      address = insert(:address)
      block = insert(:block)

      60
      |> insert_list(:transaction, from_address: address)
      |> with_block(block)

      conn = get(conn, "/txs")

      refute conn.assigns.prev_page_params
    end

    test "first_page_params exist if not on first page", %{conn: conn} do
      address = insert(:address)
      block = insert(:block)

      60
      |> insert_list(:transaction, from_address: address)
      |> with_block(block)

      conn = get(conn, "/txs?p=2")

      assert %{} = conn.assigns.first_page_params
    end

    test "first_page_params are empty if on first page", %{conn: conn} do
      address = insert(:address)
      block = insert(:block)

      60
      |> insert_list(:transaction, from_address: address)
      |> with_block(block)

      conn = get(conn, "/txs")

      refute conn.assigns.first_page_params
    end

    # test "next_page_params are empty if on last page", %{conn: conn} do
    #   address = insert(:address)

    #   :transaction
    #   |> insert(from_address: address)
    #   |> with_block()

    #   conn = get(conn, "/txs")

    #   refute conn.assigns.next_page_params
    # end

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
