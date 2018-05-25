defmodule ExplorerWeb.PendingTransactionControllerTest do
  use ExplorerWeb.ConnCase

  import ExplorerWeb.Router.Helpers, only: [pending_transaction_path: 3]

  describe "GET index/2" do
    test "returns no transactions that are in a block", %{conn: conn} do
      block = insert(:block)
      insert(:transaction, block_hash: block.hash, index: 0)

      conn = get(conn, pending_transaction_path(ExplorerWeb.Endpoint, :index, :en))

      assert html_response(conn, 200)
      assert Enum.empty?(conn.assigns.transactions)
    end

    test "does not count transactions that have a receipt", %{conn: conn} do
      block = insert(:block)
      transaction = insert(:transaction, block_hash: block.hash, index: 0)
      insert(:receipt, transaction_hash: transaction.hash, transaction_index: transaction.index)

      conn = get(conn, pending_transaction_path(ExplorerWeb.Endpoint, :index, :en))

      assert html_response(conn, 200)
      assert Enum.empty?(conn.assigns.transactions)
    end

    test "returns pending transactions", %{conn: conn} do
      transaction = insert(:transaction)

      conn = get(conn, pending_transaction_path(ExplorerWeb.Endpoint, :index, :en))

      actual_transaction_hashes =
        conn.assigns.transactions
        |> Enum.map(fn transaction -> transaction.hash end)

      assert html_response(conn, 200)
      assert Enum.member?(actual_transaction_hashes, transaction.hash)
    end

    test "returns a count of pending transactions", %{conn: conn} do
      insert(:transaction)

      conn = get(conn, pending_transaction_path(ExplorerWeb.Endpoint, :index, :en))

      assert html_response(conn, 200)
      assert 1 == conn.assigns.transaction_count
    end

    test "paginates transactions using the last seen transaction", %{conn: conn} do
      {:ok, first_inserted_at, 0} = DateTime.from_iso8601("2015-01-23T23:50:07Z")
      insert(:transaction, inserted_at: first_inserted_at)
      {:ok, second_inserted_at, 0} = DateTime.from_iso8601("2016-01-23T23:50:07Z")
      insert(:transaction, inserted_at: second_inserted_at)

      conn =
        get(
          conn,
          pending_transaction_path(ExplorerWeb.Endpoint, :index, :en),
          last_seen_pending_inserted_at: Timex.format!(first_inserted_at, "{ISO:Extended:Z}")
        )

      assert html_response(conn, 200)
      assert 1 == Enum.count(conn.assigns.transactions)
    end

    test "works when there are no transactions", %{conn: conn} do
      conn = get(conn, pending_transaction_path(conn, :index, :en))

      assert html_response(conn, 200)
    end
  end
end
