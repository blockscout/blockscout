defmodule ExplorerWeb.TransactionLogControllerTest do
  use ExplorerWeb.ConnCase

  import ExplorerWeb.Router.Helpers, only: [transaction_log_path: 4]

  describe "GET index/2" do
    test "without transaction", %{conn: conn} do
      conn = get(conn, transaction_log_path(conn, :index, :en, "unknown"))

      assert html_response(conn, 404)
    end

    test "returns logs for the transaction", %{conn: conn} do
      transaction = insert(:transaction)
      receipt = insert(:receipt, transaction: transaction)
      address = insert(:address)
      insert(:log, receipt: receipt, address_hash: address.hash)

      conn = get(conn, transaction_log_path(ExplorerWeb.Endpoint, :index, :en, transaction))

      first_log = List.first(conn.assigns.logs.entries)
      assert first_log.receipt_id == receipt.id
    end

    test "assigns no logs when there are none", %{conn: conn} do
      transaction = insert(:transaction)
      path = transaction_log_path(ExplorerWeb.Endpoint, :index, :en, transaction)

      conn = get(conn, path)

      assert Enum.count(conn.assigns.logs.entries) == 0
    end
  end
end
