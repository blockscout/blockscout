defmodule ExplorerWeb.TransactionControllerTest do
  use ExplorerWeb.ConnCase

  import ExplorerWeb.Router.Helpers, only: [transaction_path: 4, transaction_internal_transaction_path: 4]

  describe "GET index/2" do
    test "returns a transaction with a receipt", %{conn: conn} do
      transaction =
        :transaction
        |> insert()
        |> validate()

      conn = get(conn, "/en/transactions")

      assert List.first(conn.assigns.transactions).hash == transaction.hash
    end

    test "returns a count of transactions", %{conn: conn} do
      block = insert(:block)
      transaction = insert(:transaction, block_hash: block.hash, index: 0)
      insert(:receipt, transaction_hash: transaction.hash, transaction_index: transaction.index)

      conn = get(conn, "/en/transactions")

      assert length(conn.assigns.transactions) == 1
    end

    test "returns no pending transactions", %{conn: conn} do
      insert(:transaction)

      conn = get(conn, "/en/transactions")

      assert conn.assigns.transactions == []
    end

    test "only returns transactions that have a receipt", %{conn: conn} do
      insert(:transaction)

      conn = get(conn, "/en/transactions")

      assert length(conn.assigns.transactions) == 0
    end

    test "paginates transactions using the last seen transaction", %{conn: conn} do
      block = insert(:block)
      transaction = insert(:transaction, block_hash: block.hash, index: 0)
      insert(:receipt, transaction_hash: transaction.hash, transaction_index: transaction.index)

      conn =
        get(
          conn,
          "/en/transactions",
          last_seen_collated_hash: to_string(transaction.hash)
        )

      assert conn.assigns.transactions == []
    end

    test "sends back the number of transactions", %{conn: conn} do
      insert(:transaction)

      conn = get(conn, "/en/transactions")

      refute conn.assigns.transaction_count == nil
    end

    test "works when there are no transactions", %{conn: conn} do
      conn = get(conn, "/en/transactions")

      assert conn.assigns.transaction_count == 0
      assert conn.assigns.transactions == []
    end
  end

  describe "GET show/3" do
    test "redirects to transactions/:transaction_id/internal_transactions", %{conn: conn} do
      locale = "en"
      hash = "0x9"
      conn = get(conn, transaction_path(ExplorerWeb.Endpoint, :show, locale, hash))

      assert redirected_to(conn) =~ transaction_internal_transaction_path(ExplorerWeb.Endpoint, :index, locale, hash)
    end
  end
end
