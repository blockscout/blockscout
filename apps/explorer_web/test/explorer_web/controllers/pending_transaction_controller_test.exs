defmodule ExplorerWeb.PendingTransactionControllerTest do
  use ExplorerWeb.ConnCase

  import ExplorerWeb.Router.Helpers, only: [pending_transaction_path: 3]

  describe "GET index/2" do
    test "returns no transactions that have a receipt", %{conn: conn} do
      transaction = insert(:transaction)
      block = insert(:block)
      address = insert(:address)
      insert(:receipt, transaction: transaction)
      insert(:block_transaction, transaction: transaction, block: block)
      insert(:to_address, transaction: transaction, address: address)
      insert(:from_address, transaction: transaction, address: address)

      conn = get(conn, pending_transaction_path(ExplorerWeb.Endpoint, :index, :en))

      assert html = html_response(conn, 200)

      assert html =~ ~r/Showing 0 Pending Transactions/
      refute html =~ ~r/transactions__row/
    end

    test "does not count transactions that have a receipt", %{conn: conn} do
      transaction = insert(:transaction)
      block = insert(:block)
      address = insert(:address)
      insert(:receipt, transaction: transaction)
      insert(:block_transaction, transaction: transaction, block: block)
      insert(:to_address, transaction: transaction, address: address)
      insert(:from_address, transaction: transaction, address: address)

      conn = get(conn, pending_transaction_path(ExplorerWeb.Endpoint, :index, :en))

      assert html = html_response(conn, 200)

      assert html =~ ~r/Showing 0 Pending Transactions/
      refute html =~ ~r/transactions__row/
    end

    test "returns pending transactions", %{conn: conn} do
      address = insert(:address)
      transaction = insert(:transaction)
      insert(:to_address, transaction: transaction, address: address)
      insert(:from_address, transaction: transaction, address: address)

      conn = get(conn, pending_transaction_path(ExplorerWeb.Endpoint, :index, :en))

      assert html_response(conn, 200) =~ transaction.hash
    end

    test "returns a count of pending transactions", %{conn: conn} do
      address = insert(:address)
      transaction = insert(:transaction)
      insert(:to_address, transaction: transaction, address: address)
      insert(:from_address, transaction: transaction, address: address)

      conn = get(conn, pending_transaction_path(ExplorerWeb.Endpoint, :index, :en))

      assert html_response(conn, 200) =~ ~r/Showing 1 Pending Transactions/
    end

    test "paginates transactions using the last seen transaction", %{conn: conn} do
      address = insert(:address)
      transaction = insert(:transaction)
      insert(:to_address, transaction: transaction, address: address)
      insert(:from_address, transaction: transaction, address: address)

      conn =
        get(
          conn,
          pending_transaction_path(ExplorerWeb.Endpoint, :index, :en),
          last_seen: transaction.id
        )

      refute html_response(conn, 200) =~ ~r/transactions__row/
    end

    test "sends back an estimate of the number of transactions", %{conn: conn} do
      insert(:transaction)
      conn = get(conn, pending_transaction_path(ExplorerWeb.Endpoint, :index, :en))

      assert html_response(conn, 200) =~ ~r/Showing 1 Pending Transactions/
    end

    test "works when there are no transactions", %{conn: conn} do
      conn = get(conn, pending_transaction_path(ExplorerWeb.Endpoint, :index, :en))

      assert html = html_response(conn, 200)

      assert html =~ ~r/Showing 0 Pending Transactions/
      refute html =~ ~r/transactions__row/
    end
  end
end
