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

    test "returns pending transactions with a to address", %{conn: conn} do
      insert(:transaction) |> with_addresses(%{to: "0xfritos", from: "0xmunchos"})
      conn = get(conn, pending_transaction_path(ExplorerWeb.Endpoint, :index, :en))
      first_transaction = List.first(conn.assigns.transactions.entries)
      assert first_transaction.to_address.hash == "0xfritos"
      assert first_transaction.from_address.hash == "0xmunchos"
    end
  end
end
