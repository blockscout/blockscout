defmodule ExplorerWeb.TransactionControllerTest do
  use ExplorerWeb.ConnCase

  describe "GET show/3" do
    test "returns a transaction", %{conn: conn} do
      transaction = insert(:transaction, hash: "0x8")
      conn = get(conn, "/en/transactions/0x8")
      assert conn.assigns.transaction.id == transaction.id
    end
  end
end
