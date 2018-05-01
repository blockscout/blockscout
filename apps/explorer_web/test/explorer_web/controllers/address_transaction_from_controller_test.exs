defmodule ExplorerWeb.AddressTransactionFromControllerTest do
  use ExplorerWeb.ConnCase

  import ExplorerWeb.Router.Helpers, only: [address_transaction_from_path: 4]

  describe "GET index/2" do
    test "without address", %{conn: conn} do
      conn = get(conn, address_transaction_from_path(conn, :index, :en, "unknown"))

      assert html_response(conn, 404)
    end

    test "returns transactions from this address", %{conn: conn} do
      address = insert(:address)
      block = insert(:block)
      transaction = insert(:transaction, block_hash: block.hash, from_address_hash: address.hash, index: 0)
      insert(:receipt, transaction_hash: transaction.hash, transaction_index: transaction.index)

      conn = get(conn, address_transaction_from_path(ExplorerWeb.Endpoint, :index, :en, address.hash))

      assert html = html_response(conn, 200)

      transaction_hash_divs = Floki.find(html, "td.transactions__column--hash div.transactions__hash a")

      assert length(transaction_hash_divs) == 1

      assert List.first(transaction_hash_divs) |> Floki.attribute("href") == [
               "/en/transactions/#{Phoenix.Param.to_param(transaction)}"
             ]
    end

    test "does not return transactions to this address", %{conn: conn} do
      block = insert(:block)
      transaction = insert(:transaction, block_hash: block.hash, index: 0)
      insert(:receipt, transaction_hash: transaction.hash, transaction_index: transaction.index)
      address = insert(:address)

      conn = get(conn, address_transaction_from_path(ExplorerWeb.Endpoint, :index, :en, address.hash))

      assert html = html_response(conn, 200)
      assert html |> Floki.find("tbody tr") |> length == 0
    end

    test "does not return related transactions without a receipt", %{conn: conn} do
      block = insert(:block)
      insert(:transaction, block_hash: block.hash, index: 0)
      address = insert(:address)

      conn = get(conn, address_transaction_from_path(ExplorerWeb.Endpoint, :index, :en, address.hash))

      assert html = html_response(conn, 200)
      assert html |> Floki.find("tbody tr") |> length == 0
    end

    test "does not return related transactions without a from address", %{conn: conn} do
      block = insert(:block)
      transaction = insert(:transaction, block_hash: block.hash, index: 0)
      insert(:receipt, transaction_hash: transaction.hash, transaction_index: transaction.index)
      address = insert(:address)

      conn = get(conn, address_transaction_from_path(ExplorerWeb.Endpoint, :index, :en, address.hash))

      assert html = html_response(conn, 200)
      assert html |> Floki.find("tbody tr") |> length == 0
    end

    test "does not return related transactions without a to address", %{conn: conn} do
      block = insert(:block)
      transaction = insert(:transaction, block_hash: block.hash, index: 0)
      insert(:receipt, transaction_hash: transaction.hash, transaction_index: transaction.index)
      address = insert(:address)

      conn = get(conn, address_transaction_from_path(ExplorerWeb.Endpoint, :index, :en, address.hash))

      assert html = html_response(conn, 200)
      assert html |> Floki.find("tbody tr") |> length == 0
    end
  end
end
