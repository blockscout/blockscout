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
      block = insert(:block)

      :transaction
      |> insert()
      |> with_block(block)

      conn = get(conn, block_transaction_path(ExplorerWeb.Endpoint, :index, :en, block.number))

      assert html_response(conn, 200)
      assert 1 == Enum.count(conn.assigns.page)
    end

    test "does not return unrelated transactions", %{conn: conn} do
      insert(:transaction)
      block = insert(:block)

      conn = get(conn, block_transaction_path(ExplorerWeb.Endpoint, :index, :en, block))

      assert html_response(conn, 200)
      assert Enum.empty?(conn.assigns.page)
    end

    test "does not return related transactions without a block", %{conn: conn} do
      block = insert(:block)
      insert(:transaction)

      conn = get(conn, block_transaction_path(ExplorerWeb.Endpoint, :index, :en, block))

      assert html_response(conn, 200)
      assert Enum.empty?(conn.assigns.page)
    end

    test "does not return related transactions without a to address", %{conn: conn} do
      block = insert(:block)

      :transaction
      |> insert(to_address_hash: nil)
      |> with_block(block)

      conn = get(conn, block_transaction_path(ExplorerWeb.Endpoint, :index, :en, block))

      assert html_response(conn, 200)
      assert Enum.empty?(conn.assigns.page)
    end
  end
end
