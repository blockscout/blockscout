defmodule ExplorerWeb.TransactionInternalTransactionControllerTest do
  use ExplorerWeb.ConnCase

  import ExplorerWeb.Router.Helpers, only: [transaction_internal_transaction_path: 4]

  describe "GET index/3" do
    test "without transaction", %{conn: conn} do
      conn = get(conn, transaction_internal_transaction_path(ExplorerWeb.Endpoint, :index, :en, "nope"))

      assert html_response(conn, 404)
    end

    test "includes transaction data", %{conn: conn} do
      block = insert(:block, %{number: 777})

      transaction =
        :transaction
        |> insert()
        |> with_block(block)

      conn = get(conn, transaction_internal_transaction_path(ExplorerWeb.Endpoint, :index, :en, transaction.hash))

      assert html_response(conn, 200)
      assert conn.assigns.transaction.hash == transaction.hash
    end

    test "includes internal transactions for the transaction", %{conn: conn} do
      transaction = insert(:transaction)
      expected_internal_transaction = insert(:internal_transaction, transaction_hash: transaction.hash, index: 0)
      insert(:internal_transaction, transaction_hash: transaction.hash, index: 1)

      path = transaction_internal_transaction_path(ExplorerWeb.Endpoint, :index, :en, transaction.hash)

      conn = get(conn, path)

      actual_internal_transaction_ids =
        conn.assigns.internal_transactions.entries
        |> Enum.map(fn it -> it.id end)

      assert html_response(conn, 200)

      assert Enum.member?(actual_internal_transaction_ids, expected_internal_transaction.id)
    end
  end
end
