defmodule ExplorerWeb.BlockTransactionControllerTest do
  use ExplorerWeb.ConnCase

  import ExplorerWeb.Router.Helpers, only: [block_transaction_path: 4]

  describe "GET index/2" do
    test "with invalid block number", %{conn: conn} do
      conn = get(conn, block_transaction_path(conn, :index, :en, "unknown"))

      assert html_response(conn, 404)
    end

    test "with valid block number without block", %{conn: conn} do
      conn = get(conn, block_transaction_path(conn, :index, :en, "1"))

      assert html_response(conn, 404)
    end

    test "returns transactions for the block", %{conn: conn} do
      hash = "0xsnacks"
      transaction = insert(:transaction, hash: hash)
      insert(:receipt, transaction: transaction)
      block = insert(:block)
      insert(:block_transaction, transaction: transaction, block: block)
      address = insert(:address)
      insert(:to_address, transaction: transaction, address: address)
      insert(:from_address, transaction: transaction, address: address)

      conn = get(conn, block_transaction_path(ExplorerWeb.Endpoint, :index, :en, block.number))

      assert html = html_response(conn, 200)

      transaction_hash_divs =
        Floki.find(html, "td.transactions__column--hash div.transactions__hash a")

      assert length(transaction_hash_divs) == 1

      assert List.first(transaction_hash_divs) |> Floki.attribute("href") == [
               "/en/transactions/#{hash}"
             ]
    end

    test "does not return unrelated transactions", %{conn: conn} do
      insert(:transaction)
      block = insert(:block)

      conn = get(conn, block_transaction_path(ExplorerWeb.Endpoint, :index, :en, block.number))

      refute html_response(conn, 200) =~ ~r/transactions__row/
    end

    test "does not return related transactions without a receipt", %{conn: conn} do
      transaction = insert(:transaction)
      block = insert(:block)
      insert(:block_transaction, transaction: transaction, block: block)

      conn = get(conn, block_transaction_path(ExplorerWeb.Endpoint, :index, :en, block.number))

      refute html_response(conn, 200) =~ ~r/transactions__row/
    end

    test "does not return related transactions without a from address", %{conn: conn} do
      transaction = insert(:transaction, from_address_id: nil)
      insert(:receipt, transaction: transaction)
      block = insert(:block)
      insert(:block_transaction, transaction: transaction, block: block)

      conn = get(conn, block_transaction_path(ExplorerWeb.Endpoint, :index, :en, block.number))

      refute html_response(conn, 200) =~ ~r/transactions__row/
    end

    test "does not return related transactions without a to address", %{conn: conn} do
      transaction = insert(:transaction, to_address_id: nil)
      insert(:receipt, transaction: transaction)
      block = insert(:block)
      insert(:block_transaction, transaction: transaction, block: block)

      conn = get(conn, block_transaction_path(ExplorerWeb.Endpoint, :index, :en, block.number))

      refute html_response(conn, 200) =~ ~r/transactions__row/
    end
  end
end
