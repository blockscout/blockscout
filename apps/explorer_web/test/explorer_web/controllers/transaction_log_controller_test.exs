defmodule ExplorerWeb.TransactionLogControllerTest do
  use ExplorerWeb.ConnCase

  import ExplorerWeb.Router.Helpers, only: [transaction_log_path: 4]

  describe "GET index/2" do
    test "without transaction", %{conn: conn} do
      conn = get(conn, transaction_log_path(conn, :index, :en, "unknown"))

      assert html_response(conn, 404)
    end

    test "returns logs for the transaction", %{conn: conn} do
      block = insert(:block)
      transaction = insert(:transaction, block_hash: block.hash, index: 0)
      receipt = insert(:receipt, transaction_hash: transaction.hash, transaction_index: transaction.index)
      address = insert(:address)
      insert(:log, address_hash: address.hash, transaction_hash: transaction.hash)

      conn = get(conn, transaction_log_path(conn, :index, :en, transaction))

      first_log = List.first(conn.assigns.logs.entries)
      assert first_log.transaction_hash == receipt.transaction_hash
    end

    test "assigns no logs when there are none", %{conn: conn} do
      transaction = insert(:transaction)
      path = transaction_log_path(conn, :index, :en, transaction)

      conn = get(conn, path)

      assert Enum.count(conn.assigns.logs.entries) == 0
    end
  end
end
