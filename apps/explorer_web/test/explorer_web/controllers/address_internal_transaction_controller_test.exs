defmodule ExplorerWeb.AddressInternalTransactionControllerTest do
  use ExplorerWeb.ConnCase

  import ExplorerWeb.Router.Helpers, only: [address_internal_transaction_path: 4]

  describe "GET index/3" do
    test "without address", %{conn: conn} do
      conn =
        conn
        |> get(address_internal_transaction_path(ExplorerWeb.Endpoint, :index, :en, "0xcafe"))

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
