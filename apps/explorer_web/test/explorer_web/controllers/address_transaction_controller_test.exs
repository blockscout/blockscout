defmodule ExplorerWeb.AddressTransactionControllerTest do
  use ExplorerWeb.ConnCase

  import ExplorerWeb.Router.Helpers, only: [address_transaction_path: 4]

  alias Explorer.ExchangeRates.Token

  describe "GET index/2" do
    test "with invalid address hash", %{conn: conn} do
      conn = get(conn, address_transaction_path(conn, :index, :en, "invalid_address"))

      assert html_response(conn, 404)
    end

    test "with valid address hash without address", %{conn: conn} do
      conn = get(conn, address_transaction_path(conn, :index, :en, "0x8bf38d4764929064f2d4d3a56520a76ab3df415b"))

      assert html_response(conn, 404)
    end

    test "returns transactions for the address", %{conn: conn} do
      address = insert(:address)

      block = insert(:block)

      from_transaction =
        :transaction
        |> insert(from_address_hash: address.hash)
        |> with_block(block)

      to_transaction =
        :transaction
        |> insert(to_address_hash: address.hash)
        |> with_block(block)

      conn = get(conn, address_transaction_path(conn, :index, :en, address))

      actual_transaction_hashes =
        conn.assigns.page
        |> Enum.map(fn transaction -> transaction.hash end)

      assert html_response(conn, 200)
      assert Enum.member?(actual_transaction_hashes, from_transaction.hash)
      assert Enum.member?(actual_transaction_hashes, to_transaction.hash)
    end

    test "does not return related transactions without a block", %{conn: conn} do
      address = insert(:address)

      insert(:transaction, from_address_hash: address.hash, to_address_hash: address.hash)

      conn = get(conn, address_transaction_path(ExplorerWeb.Endpoint, :index, :en, address))

      assert html_response(conn, 200)
      assert conn.status == 200
      assert Enum.empty?(conn.assigns.page)
      assert conn.status == 200
      assert Enum.empty?(conn.assigns.page)
    end

    test "includes USD exchange rate value for address in assigns", %{conn: conn} do
      address = insert(:address)

      conn = get(conn, address_transaction_path(ExplorerWeb.Endpoint, :index, :en, address.hash))

      assert %Token{} = conn.assigns.exchange_rate
    end
  end
end
