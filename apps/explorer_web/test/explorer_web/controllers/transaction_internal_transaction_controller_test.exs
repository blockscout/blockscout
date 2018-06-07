defmodule ExplorerWeb.TransactionInternalTransactionControllerTest do
  use ExplorerWeb.ConnCase

  import ExplorerWeb.Router.Helpers, only: [transaction_internal_transaction_path: 4]

  alias Explorer.ExchangeRates.Token

  describe "GET index/3" do
    test "with missing transaction", %{conn: conn} do
      hash = transaction_hash()
      conn = get(conn, transaction_internal_transaction_path(ExplorerWeb.Endpoint, :index, :en, hash))

      assert html_response(conn, 404)
    end

    test "with invalid transaction hash", %{conn: conn} do
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
        conn.assigns.page
        |> Enum.map(fn it -> it.id end)

      assert html_response(conn, 200)

      assert Enum.member?(actual_internal_transaction_ids, expected_internal_transaction.id)
    end

    test "includes USD exchange rate value for address in assigns", %{conn: conn} do
      transaction = insert(:transaction)

      conn = get(conn, transaction_internal_transaction_path(ExplorerWeb.Endpoint, :index, :en, transaction.hash))

      assert %Token{} = conn.assigns.exchange_rate
    end

    test "with no to_address_hash overview contains contract create address", %{conn: conn} do
      transaction = insert(:transaction, to_address_hash: nil)
      insert(:internal_transaction_create, transaction_hash: transaction.hash, index: 0)

      conn = get(conn, transaction_internal_transaction_path(ExplorerWeb.Endpoint, :index, :en, transaction.hash))

      refute is_nil(conn.assigns.transaction.created_contract_address_hash)
    end
  end
end
