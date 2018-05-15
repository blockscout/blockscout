defmodule ExplorerWeb.PendingTransactionControllerTest do
  use ExplorerWeb.ConnCase

  import ExplorerWeb.Router.Helpers, only: [pending_transaction_path: 3]

  describe "GET index/2" do
    test "returns no transactions that are in a block", %{conn: conn} do
      block = insert(:block)
      insert(:transaction, block_hash: block.hash, index: 0)

      conn = get(conn, pending_transaction_path(ExplorerWeb.Endpoint, :index, :en))

      assert html = html_response(conn, 200)

      assert html =~ ~r/Showing 0 Pending Transactions/
      refute html =~ ~r/transactions__row/
    end

    test "does not count transactions that have a receipt", %{conn: conn} do
      block = insert(:block)
      transaction = insert(:transaction, block_hash: block.hash, index: 0)
      insert(:receipt, transaction_hash: transaction.hash, transaction_index: transaction.index)

      conn = get(conn, pending_transaction_path(ExplorerWeb.Endpoint, :index, :en))

      assert html = html_response(conn, 200)

      assert html =~ ~r/Showing 0 Pending Transactions/
      refute html =~ ~r/transactions__row/
    end

    test "returns pending transactions", %{conn: conn} do
      transaction = insert(:transaction)

      conn = get(conn, pending_transaction_path(ExplorerWeb.Endpoint, :index, :en))

      assert html_response(conn, 200) =~ to_string(transaction.hash)
    end

    test "returns a count of pending transactions", %{conn: conn} do
      insert(:transaction)

      conn = get(conn, pending_transaction_path(ExplorerWeb.Endpoint, :index, :en))

      assert html_response(conn, 200) =~ ~r/Showing 1 Pending Transactions/
    end

    test "paginates transactions using the last seen transaction", %{conn: conn} do
      {:ok, first_inserted_at, 0} = DateTime.from_iso8601("2015-01-23T23:50:07Z")
      insert(:transaction, inserted_at: first_inserted_at)
      {:ok, second_inserted_at, 0} = DateTime.from_iso8601("2016-01-23T23:50:07Z")
      insert(:transaction, inserted_at: second_inserted_at)

      first_response_conn =
        get(
          conn,
          pending_transaction_path(ExplorerWeb.Endpoint, :index, :en),
          last_seen_pending_inserted_at: Timex.format!(first_inserted_at, "{ISO:Extended:Z}")
        )

      assert first_html = html_response(first_response_conn, 200)
      assert first_html |> Floki.find("table.transactions__table tbody tr") |> Enum.count() == 1

      second_response_conn =
        get(
          conn,
          pending_transaction_path(ExplorerWeb.Endpoint, :index, :en),
          last_seen_pending_inserted_at: Timex.format!(second_inserted_at, "{ISO:Extended:Z}")
        )

      assert second_html = html_response(second_response_conn, 200)
      assert second_html |> Floki.find("table.transactions__table tbody tr") |> Enum.count() == 0
    end

    test "sends back an estimate of the number of transactions", %{conn: conn} do
      insert(:transaction)
      conn = get(conn, pending_transaction_path(ExplorerWeb.Endpoint, :index, :en))

      assert html_response(conn, 200) =~ ~r/Showing 1 Pending Transactions/
    end

    test "works when there are no transactions", %{conn: conn} do
      conn = get(conn, pending_transaction_path(conn, :index, :en))

      assert html = html_response(conn, 200)

      assert html =~ ~r/Showing 0 Pending Transactions/
      refute html =~ ~r/transactions__row/
    end
  end
end
