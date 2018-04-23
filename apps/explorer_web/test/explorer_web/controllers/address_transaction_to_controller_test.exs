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
      transaction = insert(:transaction, block_hash: insert(:block).hash, index: 0, to_address_hash: address.hash)
      insert(:receipt, transaction: transaction)

      conn = get(conn, address_transaction_to_path(ExplorerWeb.Endpoint, :index, :en, address))

      assert html = html_response(conn, 200)
      assert html |> Floki.find("tbody tr") |> length == 1

      transaction_hash_divs = Floki.find(html, "td.transactions__column--hash div.transactions__hash a")

      assert length(transaction_hash_divs) == 1

      assert List.first(transaction_hash_divs) |> Floki.attribute("href") == [
               "/en/transactions/#{Phoenix.Param.to_param(transaction)}"
             ]
    end

    test "does not return transactions from this address", %{conn: conn} do
      transaction = insert(:transaction)
      insert(:receipt, transaction: transaction)
      address = insert(:address)

      conn = get(conn, address_transaction_to_path(ExplorerWeb.Endpoint, :index, :en, address))

      assert html = html_response(conn, 200)
      assert html |> Floki.find("tbody tr") |> length == 0
    end

    test "does not return related transactions without a receipt", %{conn: conn} do
      address = insert(:address)
      block = insert(:block)

      insert(
        :transaction,
        block_hash: block.hash,
        from_address_hash: address.hash,
        index: 0,
        to_address_hash: address.hash
      )

      conn = get(conn, address_transaction_to_path(ExplorerWeb.Endpoint, :index, :en, address))

      assert html = html_response(conn, 200)
      assert html |> Floki.find("tbody tr") |> length == 0
    end

    test "does not return related transactions without a from address", %{conn: conn} do
      transaction = insert(:transaction)
      insert(:receipt, transaction: transaction)
      address = insert(:address)

      conn = get(conn, address_transaction_to_path(ExplorerWeb.Endpoint, :index, :en, address))

      assert html = html_response(conn, 200)
      assert html |> Floki.find("tbody tr") |> length == 0
    end

    test "does not return related transactions without a to address", %{conn: conn} do
      address = insert(:address)
      block = insert(:block)
      transaction = insert(:transaction, block_hash: block.hash, from_address_hash: address.hash, index: 0)
      insert(:receipt, transaction: transaction)

      conn = get(conn, address_transaction_to_path(ExplorerWeb.Endpoint, :index, :en, address))

      assert html = html_response(conn, 200)
      assert html |> Floki.find("tbody tr") |> length == 0
    end
  end
end
