defmodule ExplorerWeb.TransactionControllerTest do
  use ExplorerWeb.ConnCase

  describe "GET show/3" do
    test "returns a transaction", %{conn: conn} do
      transaction = insert(:transaction, hash: "0x8") |> with_addresses
      conn = get(conn, "/en/transactions/0x8")
      assert conn.assigns.transaction.id == transaction.id
    end
  end

  describe "GET index/2" do
    test "returns all blocks", %{conn: conn} do
      transaction_ids = insert_list(4, :transaction) |> Enum.map(fn (transaction) -> transaction.id end)
      conn = get(conn, "/en/transactions")
      assert conn.assigns.transactions |> Enum.map(fn (transaction) -> transaction.id end) == transaction_ids
    end
  end
end
