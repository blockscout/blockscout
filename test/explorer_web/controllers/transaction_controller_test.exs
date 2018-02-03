defmodule ExplorerWeb.TransactionControllerTest do
  use ExplorerWeb.ConnCase

  describe "GET index/2" do
    test "returns all transactions", %{conn: conn} do
      transaction_ids = insert_list(4, :transaction) |> list_with_block |> Enum.map(fn (transaction) -> transaction.id end)
      conn = get(conn, "/en/transactions")
      assert conn.assigns.transactions |> Enum.map(fn (transaction) -> transaction.id end) == transaction_ids
    end
  end

  describe "GET show/3" do
    test "when there is an associated block, it returns a transaction with block data", %{conn: conn} do
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
