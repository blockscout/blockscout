defmodule ExplorerWeb.TransactionControllerTest do
  use ExplorerWeb.ConnCase

  describe "GET index/2" do
    test "returns a transaction with a receipt", %{conn: conn} do
      transaction = insert(:transaction)
      block = insert(:block)
      address = insert(:address)
      insert(:receipt, transaction: transaction)
      insert(:block_transaction, transaction: transaction, block: block)
      insert(:to_address, transaction: transaction, address: address)
      insert(:from_address, transaction: transaction, address: address)
      conn = get(conn, "/en/transactions")
      assert List.first(conn.assigns.transactions.entries).id == transaction.id
    end

    test "returns a count of transactions", %{conn: conn} do
      transaction = insert(:transaction)
      block = insert(:block)
      address = insert(:address)
      insert(:receipt, transaction: transaction)
      insert(:block_transaction, transaction: transaction, block: block)
      insert(:to_address, transaction: transaction, address: address)
      insert(:from_address, transaction: transaction, address: address)
      conn = get(conn, "/en/transactions")
      assert conn.assigns.transactions.total_entries === 1
    end

    test "returns no pending transactions", %{conn: conn} do
      insert(:transaction)
      conn = get(conn, "/en/transactions")
      assert conn.assigns.transactions.entries == []
    end

    test "returns a zero count when there are only pending transactions", %{conn: conn} do
      insert(:transaction)
      conn = get(conn, "/en/transactions")
      assert conn.assigns.transactions.total_entries === 0
    end

    test "paginates transactions using the last seen transaction", %{conn: conn} do
      transaction = insert(:transaction)
      block = insert(:block)
      address = insert(:address)
      insert(:receipt, transaction: transaction)
      insert(:block_transaction, transaction: transaction, block: block)
      insert(:to_address, transaction: transaction, address: address)
      insert(:from_address, transaction: transaction, address: address)
      conn = get(conn, "/en/transactions", last_seen: transaction.id)
      assert conn.assigns.transactions.entries == []
    end
  end

  describe "GET show/3" do
    test "when there is an associated block, it returns a transaction with block data", %{
      conn: conn
    } do
      block = insert(:block, %{number: 777})
      transaction = insert(:transaction, hash: "0x8") |> with_block(block) |> with_addresses
      conn = get(conn, "/en/transactions/0x8")
      assert conn.assigns.transaction.id == transaction.id
      assert conn.assigns.transaction.block_number == block.number
    end

    test "returns a transaction without associated block data", %{conn: conn} do
      transaction = insert(:transaction, hash: "0x8") |> with_addresses
      conn = get(conn, "/en/transactions/0x8")
      assert conn.assigns.transaction.id == transaction.id
      assert conn.assigns.transaction.block_number == ""
    end
  end
end
