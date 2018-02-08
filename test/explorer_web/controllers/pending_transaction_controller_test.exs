defmodule ExplorerWeb.PendingTransactionControllerTest do
  use ExplorerWeb.ConnCase

  import ExplorerWeb.Router.Helpers, only: [pending_transaction_path: 3]

  describe "GET index/2" do
    test "does not return transactions with a block", %{conn: conn} do
      block = insert(:block)
      transaction = insert(:transaction)
      insert(:block_transaction, block: block, transaction: transaction)
      conn = get(conn, pending_transaction_path(ExplorerWeb.Endpoint, :index, :en))
      assert conn.assigns.transactions |> Enum.count == 0
    end

    test "returns pending transactions", %{conn: conn} do
      transaction = insert(:transaction)
      conn = get(conn, pending_transaction_path(ExplorerWeb.Endpoint, :index, :en))
      assert List.first(conn.assigns.transactions.entries).id == transaction.id
    end
  end
end
