defmodule ExplorerWeb.TransactionLogControllerTest do
  use ExplorerWeb.ConnCase

  import ExplorerWeb.Router.Helpers, only: [transaction_log_path: 4]

  describe "GET index/2" do
    test "returns logs for the transaction", %{conn: conn} do
      transaction = insert(:transaction)
      receipt = insert(:receipt, transaction: transaction)
      address = insert(:address)
      insert(:log, receipt: receipt, address: address)
      path = transaction_log_path(ExplorerWeb.Endpoint, :index, :en, transaction.hash)
      conn = get(conn, path)
      first_log = List.first(conn.assigns.logs.entries)
      assert first_log.receipt_id == receipt.id
    end

    test "assigns no logs when there are none", %{conn: conn} do
      transaction = insert(:transaction)
      path = transaction_log_path(ExplorerWeb.Endpoint, :index, :en, transaction.hash)
      conn = get(conn, path)
      assert Enum.count(conn.assigns.logs.entries) == 0
    end
  end
end
