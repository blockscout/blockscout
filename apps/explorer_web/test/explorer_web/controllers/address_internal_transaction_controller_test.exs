defmodule ExplorerWeb.AddressInternalTransactionControllerTest do
  use ExplorerWeb.ConnCase

  import ExplorerWeb.Router.Helpers, only: [address_internal_transaction_path: 4]

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
      block = insert(:block)
      transaction = insert(:transaction, block_hash: block.hash, index: 0)

      from_internal_transaction =
        insert(:internal_transaction, transaction_hash: transaction.hash, from_address_hash: address.hash, index: 1)

      to_internal_transaction =
        insert(:internal_transaction, transaction_hash: transaction.hash, to_address_hash: address.hash, index: 2)

      path = address_internal_transaction_path(ExplorerWeb.Endpoint, :index, :en, address)

      conn = get(conn, path)

      actual_transaction_ids =
        conn.assigns.page
        |> Enum.map(fn internal_transaction -> internal_transaction.id end)

      assert Enum.member?(actual_transaction_ids, from_internal_transaction.id)
      assert Enum.member?(actual_transaction_ids, to_internal_transaction.id)
    end
  end
end
