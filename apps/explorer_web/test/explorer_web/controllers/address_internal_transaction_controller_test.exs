defmodule ExplorerWeb.AddressInternalTransactionControllerTest do
  use ExplorerWeb.ConnCase

  import ExplorerWeb.Router.Helpers, only: [address_internal_transaction_path: 4]

  alias Explorer.ExchangeRates.Token

  describe "GET index/3" do
    test "with invalid address hash", %{conn: conn} do
      conn =
        conn
        |> get(address_internal_transaction_path(ExplorerWeb.Endpoint, :index, :en, "invalid_address"))

      assert html_response(conn, 404)
    end

    test "with valid address hash without address", %{conn: conn} do
      conn =
        get(conn, address_internal_transaction_path(conn, :index, :en, "0x8bf38d4764929064f2d4d3a56520a76ab3df415b"))

      assert html_response(conn, 404)
    end

    test "returns internal transactions for the address", %{conn: conn} do
      address = insert(:address)

      transaction =
        :transaction
        |> insert()
        |> with_block()

      from_internal_transaction =
        insert(:internal_transaction, transaction_hash: transaction.hash, from_address_hash: address.hash, index: 1)

      to_internal_transaction =
        insert(:internal_transaction, transaction_hash: transaction.hash, to_address_hash: address.hash, index: 2)

      path = address_internal_transaction_path(conn, :index, :en, address)
      conn = get(conn, path)

      actual_transaction_ids =
        conn.assigns.page
        |> Enum.map(fn internal_transaction -> internal_transaction.id end)

      assert Enum.member?(actual_transaction_ids, from_internal_transaction.id)
      assert Enum.member?(actual_transaction_ids, to_internal_transaction.id)
    end

    test "includes USD exchange rate value for address in assigns", %{conn: conn} do
      address = insert(:address)

      conn = get(conn, address_internal_transaction_path(ExplorerWeb.Endpoint, :index, :en, address.hash))

      assert %Token{} = conn.assigns.exchange_rate
    end
  end
end
