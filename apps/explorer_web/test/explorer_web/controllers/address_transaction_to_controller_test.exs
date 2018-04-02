defmodule ExplorerWeb.AddressTransactionToControllerTest do
  use ExplorerWeb.ConnCase

  import ExplorerWeb.Router.Helpers, only: [address_transaction_to_path: 4]

  describe "GET index/2" do
    test "without address", %{conn: conn} do
      conn = get(conn, address_transaction_to_path(conn, :index, :en, "unknown"))

      assert html_response(conn, 404)
    end

    test "returns transactions to this address", %{conn: conn} do
      address = insert(:address)
      hash = "0xsnacks"
      transaction = insert(:transaction, block_id: insert(:block).id, hash: hash, to_address_id: address.id)
      insert(:receipt, transaction: transaction)

      conn = get(conn, address_transaction_to_path(ExplorerWeb.Endpoint, :index, :en, address.hash))

      assert html = html_response(conn, 200)
      assert html |> Floki.find("tbody tr") |> length == 1

      transaction_hash_divs = Floki.find(html, "td.transactions__column--hash div.transactions__hash a")

      assert length(transaction_hash_divs) == 1

      assert List.first(transaction_hash_divs) |> Floki.attribute("href") == [
               "/en/transactions/#{hash}"
             ]
    end

    test "does not return transactions from this address", %{conn: conn} do
      transaction = insert(:transaction, hash: "0xsnacks")
      insert(:receipt, transaction: transaction)
      address = insert(:address)

      conn = get(conn, address_transaction_to_path(ExplorerWeb.Endpoint, :index, :en, address.hash))

      assert html = html_response(conn, 200)
      assert html |> Floki.find("tbody tr") |> length == 0
    end

    test "does not return related transactions without a receipt", %{conn: conn} do
      address = insert(:address)
      block = insert(:block)
      insert(:transaction, block_id: block.id, from_address_id: address.id, to_address_id: address.id)

      conn = get(conn, address_transaction_to_path(ExplorerWeb.Endpoint, :index, :en, address.hash))

      assert html = html_response(conn, 200)
      assert html |> Floki.find("tbody tr") |> length == 0
    end

    test "does not return related transactions without a from address", %{conn: conn} do
      transaction = insert(:transaction)
      insert(:receipt, transaction: transaction)
      address = insert(:address)

      conn = get(conn, address_transaction_to_path(ExplorerWeb.Endpoint, :index, :en, address.hash))

      assert html = html_response(conn, 200)
      assert html |> Floki.find("tbody tr") |> length == 0
    end

    test "does not return related transactions without a to address", %{conn: conn} do
      address = insert(:address)
      block = insert(:block)
      transaction = insert(:transaction, block_id: block.id, from_address_id: address.id)
      insert(:receipt, transaction: transaction)

      conn = get(conn, address_transaction_to_path(ExplorerWeb.Endpoint, :index, :en, address.hash))

      assert html = html_response(conn, 200)
      assert html |> Floki.find("tbody tr") |> length == 0
    end
  end
end
