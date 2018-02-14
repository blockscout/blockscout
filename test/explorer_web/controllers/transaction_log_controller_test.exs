defmodule ExplorerWeb.TransactionLogControllerTest do
  use ExplorerWeb.ConnCase

  import ExplorerWeb.Router.Helpers, only: [transaction_log_path: 4]

  describe "GET index/2" do
    test "returns logs for the transaction", %{conn: conn} do
      transaction = insert(:transaction)
      transaction_receipt = insert(:transaction_receipt, transaction: transaction)
      address = insert(:address)
      insert(:log, transaction_receipt: transaction_receipt, address: address)
      path = transaction_log_path(ExplorerWeb.Endpoint, :index, :en, transaction.hash)
      conn = get(conn, path)
      first_log = List.first(conn.assigns.logs.entries)
      assert first_log.transaction_receipt_id == transaction_receipt.id
    end

    test "assigns no logs when there are none", %{conn: conn} do
      transaction = insert(:transaction)
      path = transaction_log_path(ExplorerWeb.Endpoint, :index, :en, transaction.hash)
      conn = get(conn, path)
      assert Enum.count(conn.assigns.logs.entries) == 0
    end
  end
end
