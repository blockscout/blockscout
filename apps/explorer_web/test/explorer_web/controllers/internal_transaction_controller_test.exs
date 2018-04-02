defmodule ExplorerWeb.InternalTransactionControllerTest do
  use ExplorerWeb.ConnCase

  import ExplorerWeb.Router.Helpers, only: [transaction_internal_transaction_path: 4]

  describe "GET index/2" do
    test "returns internal transactions for the transaction", %{conn: conn} do
      transaction = insert(:transaction)
      internal_transaction = insert(:internal_transaction, transaction_id: transaction.id)

      path =
        transaction_internal_transaction_path(ExplorerWeb.Endpoint, :index, :en, transaction.hash)

      conn = get(conn, path)

      first_internal_transaction = List.first(conn.assigns.internal_transactions)

      assert conn.assigns.transaction_hash == transaction.hash
      assert first_internal_transaction.id == internal_transaction.id
    end
  end
end
