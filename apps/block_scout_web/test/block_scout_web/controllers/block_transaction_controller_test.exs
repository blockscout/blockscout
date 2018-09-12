defmodule BlockScoutWeb.BlockTransactionControllerTest do
  use BlockScoutWeb.ConnCase

  alias Explorer.Chain.Block
  import BlockScoutWeb.Router.Helpers, only: [block_transaction_path: 3]

  describe "GET index/2" do
    test "with invalid block number", %{conn: conn} do
      conn = get(conn, block_transaction_path(conn, :index, "unknown"))

      assert html_response(conn, 404)
    end

    test "with valid block number without block", %{conn: conn} do
      conn = get(conn, block_transaction_path(conn, :index, "1"))

      assert html_response(conn, 404)
    end

    test "returns transactions for the block", %{conn: conn} do
      block = insert(:block)

      :transaction
      |> insert()
      |> with_block(block)

      :transaction
      |> insert(to_address: nil)
      |> with_block(block)
      |> with_contract_creation(insert(:contract_address))

      conn = get(conn, block_transaction_path(BlockScoutWeb.Endpoint, :index, block.number))

      assert html_response(conn, 200)
      assert 2 == Enum.count(conn.assigns.transactions)
    end

    test "does not return unrelated transactions", %{conn: conn} do
      insert(:transaction)
      block = insert(:block)

      conn = get(conn, block_transaction_path(BlockScoutWeb.Endpoint, :index, block))

      assert html_response(conn, 200)
      assert Enum.empty?(conn.assigns.transactions)
    end

    test "does not return related transactions without a block", %{conn: conn} do
      block = insert(:block)
      insert(:transaction)

      conn = get(conn, block_transaction_path(BlockScoutWeb.Endpoint, :index, block))

      assert html_response(conn, 200)
      assert Enum.empty?(conn.assigns.transactions)
    end

    test "next_page_params exist if not on last page", %{conn: conn} do
      block = %Block{number: number} = insert(:block)

      60
      |> insert_list(:transaction)
      |> with_block(block)

      conn = get(conn, block_transaction_path(BlockScoutWeb.Endpoint, :index, block))

      assert %{"block_number" => ^number, "index" => 10} = conn.assigns.next_page_params
    end

    test "next_page_params are empty if on last page", %{conn: conn} do
      block = insert(:block)

      :transaction
      |> insert()
      |> with_block(block)

      conn = get(conn, block_transaction_path(BlockScoutWeb.Endpoint, :index, block))

      refute conn.assigns.next_page_params
    end
  end
end
