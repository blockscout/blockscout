defmodule ExplorerWeb.AddressTransactionToControllerTest do
  use ExplorerWeb.ConnCase

  import ExplorerWeb.Router.Helpers, only: [address_transaction_to_path: 4]

  describe "GET index/2" do
    test "returns transactions to this address", %{conn: conn} do
      address = insert(:address)
      transaction = insert(:transaction, hash: "0xsnacks", to_address_id: address.id)
      insert(:receipt, transaction: transaction)
      block = insert(:block)
      insert(:block_transaction, transaction: transaction, block: block)

      conn =
        get(conn, address_transaction_to_path(ExplorerWeb.Endpoint, :index, :en, address.hash))

      assert conn.assigns.transactions.total_entries == 1
      assert List.first(conn.assigns.transactions.entries).hash == "0xsnacks"
    end

    test "does not return transactions from this address", %{conn: conn} do
      transaction = insert(:transaction, hash: "0xsnacks")
      insert(:receipt, transaction: transaction)
      block = insert(:block)
      insert(:block_transaction, transaction: transaction, block: block)
      address = insert(:address)
      other_address = insert(:address)
      insert(:to_address, transaction: transaction, address: other_address)
      insert(:from_address, transaction: transaction, address: address)

      conn =
        get(conn, address_transaction_to_path(ExplorerWeb.Endpoint, :index, :en, address.hash))

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
        get(conn, address_transaction_to_path(ExplorerWeb.Endpoint, :index, :en, address.hash))

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
        get(conn, address_transaction_to_path(ExplorerWeb.Endpoint, :index, :en, address.hash))

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
        get(conn, address_transaction_to_path(ExplorerWeb.Endpoint, :index, :en, address.hash))

      assert conn.assigns.transactions.total_entries == 0
    end
  end
end
