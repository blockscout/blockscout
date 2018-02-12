defmodule ExplorerWeb.PendingTransactionControllerTest do
  use ExplorerWeb.ConnCase

  import ExplorerWeb.Router.Helpers, only: [pending_transaction_path: 3]

  describe "GET index/2" do
    test "returns pending transactions with addresses", %{conn: conn} do
      transaction = insert(:transaction) |> with_addresses(%{to: "0xfritos", from: "0xmunchos"})
      conn = get(conn, pending_transaction_path(ExplorerWeb.Endpoint, :index, :en))
      first_transaction = List.first(conn.assigns.transactions.entries)
      assert first_transaction.id == transaction.id
      assert first_transaction.to_address.hash == "0xfritos"
      assert first_transaction.from_address.hash == "0xmunchos"
    end

    test "doesn't return pending transactions without addresses", %{conn: conn} do
      insert(:transaction)
      conn = get(conn, pending_transaction_path(ExplorerWeb.Endpoint, :index, :en))
      assert length(conn.assigns.transactions.entries) == 0
    end

    test "does not return transactions with a block", %{conn: conn} do
      block = insert(:block)
      transaction = insert(:transaction)
      insert(:block_transaction, block: block, transaction: transaction)
      conn = get(conn, pending_transaction_path(ExplorerWeb.Endpoint, :index, :en))
      assert conn.assigns.transactions |> Enum.count == 0
    end
  end
end
