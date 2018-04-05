defmodule ExplorerWeb.BlockTransactionControllerTest do
  use ExplorerWeb.ConnCase

  import ExplorerWeb.Router.Helpers, only: [block_transaction_path: 4]

  describe "GET index/2" do
    test "with invalid block number", %{conn: conn} do
      conn = get(conn, block_transaction_path(conn, :index, :en, "unknown"))

      assert html_response(conn, 404)
    end

    test "with valid block number without block", %{conn: conn} do
      conn = get(conn, block_transaction_path(conn, :index, :en, "1"))

      assert html_response(conn, 404)
    end

    test "returns transactions for the block", %{conn: conn} do
      transaction = insert(:transaction, hash: "0xsnacks")
      insert(:receipt, transaction: transaction)
      block = insert(:block)
      insert(:block_transaction, transaction: transaction, block: block)
      address = insert(:address)
      insert(:to_address, transaction: transaction, address: address)
      insert(:from_address, transaction: transaction, address: address)
      conn = get(conn, block_transaction_path(ExplorerWeb.Endpoint, :index, :en, block.number))
      assert conn.assigns.transactions.total_entries == 1
      assert List.first(conn.assigns.transactions.entries).hash == "0xsnacks"
    end

    test "does not return unrelated transactions", %{conn: conn} do
      insert(:transaction)
      block = insert(:block)
      conn = get(conn, block_transaction_path(ExplorerWeb.Endpoint, :index, :en, block.number))
      assert conn.assigns.transactions.total_entries == 0
    end

    test "does not return related transactions without a receipt", %{conn: conn} do
      transaction = insert(:transaction)
      block = insert(:block)
      insert(:block_transaction, transaction: transaction, block: block)
      conn = get(conn, block_transaction_path(ExplorerWeb.Endpoint, :index, :en, block.number))
      assert conn.assigns.transactions.total_entries == 0
    end

    test "does not return related transactions without a from address", %{conn: conn} do
      transaction = insert(:transaction, from_address_id: nil)
      insert(:receipt, transaction: transaction)
      block = insert(:block)
      insert(:block_transaction, transaction: transaction, block: block)
      conn = get(conn, block_transaction_path(ExplorerWeb.Endpoint, :index, :en, block.number))
      assert conn.assigns.transactions.total_entries == 0
    end

    test "does not return related transactions without a to address", %{conn: conn} do
      transaction = insert(:transaction, to_address_id: nil)
      insert(:receipt, transaction: transaction)
      block = insert(:block)
      insert(:block_transaction, transaction: transaction, block: block)
      conn = get(conn, block_transaction_path(ExplorerWeb.Endpoint, :index, :en, block.number))
      assert conn.assigns.transactions.total_entries == 0
    end
  end
end
