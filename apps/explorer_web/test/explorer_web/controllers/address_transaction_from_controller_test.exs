defmodule ExplorerWeb.AddressTransactionFromControllerTest do
  use ExplorerWeb.ConnCase

  import ExplorerWeb.Router.Helpers, only: [address_transaction_from_path: 4]

  describe "GET index/2" do
    test "without address", %{conn: conn} do
      conn = get(conn, address_transaction_from_path(conn, :index, :en, "unknown"))

      assert html_response(conn, 404)
    end

    test "returns transactions from this address", %{conn: conn} do
      address = insert(:address)
      transaction = insert(:transaction, hash: "0xsnacks", from_address_id: address.id)
      insert(:receipt, transaction: transaction)
      block = insert(:block)
      insert(:block_transaction, transaction: transaction, block: block)

      conn =
        get(conn, address_transaction_from_path(ExplorerWeb.Endpoint, :index, :en, address.hash))

      assert conn.assigns.transactions.total_entries == 1
      assert List.first(conn.assigns.transactions.entries).hash == "0xsnacks"
    end

    test "does not return transactions to this address", %{conn: conn} do
      transaction = insert(:transaction, hash: "0xsnacks")
      insert(:receipt, transaction: transaction)
      block = insert(:block)
      insert(:block_transaction, transaction: transaction, block: block)
      address = insert(:address)
      other_address = insert(:address)
      insert(:to_address, transaction: transaction, address: address)
      insert(:from_address, transaction: transaction, address: other_address)

      conn =
        get(conn, address_transaction_from_path(ExplorerWeb.Endpoint, :index, :en, address.hash))

      assert conn.assigns.transactions.total_entries == 0
    end

    test "does not return related transactions without a receipt", %{conn: conn} do
      transaction = insert(:transaction)
      block = insert(:block)
      insert(:block_transaction, transaction: transaction, block: block)
      address = insert(:address)
      insert(:to_address, transaction: transaction, address: address)
      insert(:from_address, transaction: transaction, address: address)

      conn =
        get(conn, address_transaction_from_path(ExplorerWeb.Endpoint, :index, :en, address.hash))

      assert conn.assigns.transactions.total_entries == 0
    end

    test "does not return related transactions without a from address", %{conn: conn} do
      transaction = insert(:transaction)
      insert(:receipt, transaction: transaction)
      block = insert(:block)
      insert(:block_transaction, transaction: transaction, block: block)
      address = insert(:address)
      insert(:to_address, transaction: transaction, address: address)

      conn =
        get(conn, address_transaction_from_path(ExplorerWeb.Endpoint, :index, :en, address.hash))

      assert conn.assigns.transactions.total_entries == 0
    end

    test "does not return related transactions without a to address", %{conn: conn} do
      transaction = insert(:transaction)
      insert(:receipt, transaction: transaction)
      block = insert(:block)
      insert(:block_transaction, transaction: transaction, block: block)
      address = insert(:address)
      insert(:from_address, transaction: transaction, address: address)

      conn =
        get(conn, address_transaction_from_path(ExplorerWeb.Endpoint, :index, :en, address.hash))

      assert conn.assigns.transactions.total_entries == 0
    end
  end
end
