defmodule ExplorerWeb.TransactionLogControllerTest do
  use ExplorerWeb.ConnCase

  import ExplorerWeb.Router.Helpers, only: [transaction_log_path: 4]

  alias Explorer.ExchangeRates.Token

  describe "GET index/2" do
    test "with invalid transaction hash", %{conn: conn} do
      conn = get(conn, transaction_log_path(conn, :index, :en, "invalid_transaction_string"))

      assert html_response(conn, 404)
    end

    test "with valid transaction hash without transaction", %{conn: conn} do
      conn =
        get(
          conn,
          transaction_log_path(conn, :index, :en, "0x3a3eb134e6792ce9403ea4188e5e79693de9e4c94e499db132be086400da79e6")
        )

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

  test "includes USD exchange rate value for address in assigns", %{conn: conn} do
    transaction = insert(:transaction)

    conn = get(conn, transaction_log_path(ExplorerWeb.Endpoint, :index, :en, transaction.hash))

    assert %Token{} = conn.assigns.exchange_rate
  end
end
