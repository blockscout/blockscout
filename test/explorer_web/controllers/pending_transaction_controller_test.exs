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
      assert conn.assigns.transactions.entries == []
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
      assert conn.assigns.transactions.total_entries === 0
    end

    test "returns pending transactions", %{conn: conn} do
      address = insert(:address)
      transaction = insert(:transaction)
      insert(:to_address, transaction: transaction, address: address)
      insert(:from_address, transaction: transaction, address: address)
      conn = get(conn, pending_transaction_path(ExplorerWeb.Endpoint, :index, :en))
      assert List.first(conn.assigns.transactions.entries).id == transaction.id
    end

    test "returns a count of pending transactions", %{conn: conn} do
      address = insert(:address)
      transaction = insert(:transaction)
      insert(:to_address, transaction: transaction, address: address)
      insert(:from_address, transaction: transaction, address: address)
      conn = get(conn, pending_transaction_path(ExplorerWeb.Endpoint, :index, :en))
      assert conn.assigns.transactions.total_entries === 1
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

      assert conn.assigns.transactions.entries == []
    end
  end
end
