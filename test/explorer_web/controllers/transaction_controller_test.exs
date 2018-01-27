defmodule ExplorerWeb.TransactionControllerTest do
  use ExplorerWeb.ConnCase

  describe "GET show/3" do
    test "returns a transaction", %{conn: conn} do
      insert(:transaction, id: 8)
      conn = get(conn, "/en/transactions/8")
      assert conn.assigns.transaction.id == 8
    end
  end
end
