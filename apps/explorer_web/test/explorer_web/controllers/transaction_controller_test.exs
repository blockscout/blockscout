defmodule ExplorerWeb.TransactionControllerTest do
  use ExplorerWeb.ConnCase

  import ExplorerWeb.Router.Helpers, only: [transaction_path: 4]

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
    test "without transaction", %{conn: conn} do
      conn = get(conn, "/en/transactions/0x1")

      assert html_response(conn, 404)
    end

    test "when there is an associated block, it returns a transaction with block data", %{
      conn: conn
    } do
      block = insert(:block, %{number: 777})
      transaction = insert(:transaction, block_hash: block.hash, index: 0)

      conn = get(conn, transaction_path(conn, :show, :en, transaction))

      assert html = html_response(conn, 200)

      assert html |> Floki.find("div.transaction__header h3") |> Floki.text() == to_string(transaction.hash)

      assert html |> Floki.find("span.transaction__item--primary a") |> Floki.text() == to_string(block.number)
    end

    test "returns a transaction without associated block data", %{conn: conn} do
      transaction = insert(:transaction)

      conn = get(conn, transaction_path(conn, :show, :en, transaction))

      assert html = html_response(conn, 200)

      assert html |> Floki.find("div.transaction__header h3") |> Floki.text() == to_string(transaction.hash)
      assert html |> Floki.find("span.transaction__item--primary a") |> Floki.text() == ""
    end

    test "returns internal transactions for the transaction", %{conn: conn} do
      block = insert(:block)
      transaction = insert(:transaction, block_hash: block.hash, index: 0)
      receipt = insert(:receipt, transaction_hash: transaction.hash, transaction_index: transaction.index)
      internal_transaction = insert(:internal_transaction, transaction_hash: receipt.transaction_hash, index: 0)

      path = transaction_path(ExplorerWeb.Endpoint, :show, :en, transaction)

      conn = get(conn, path)

      assert [first_internal_transaction] = conn.assigns.internal_transactions

      assert conn.assigns.transaction.hash == transaction.hash
      assert first_internal_transaction.id == internal_transaction.id
    end
  end
end
