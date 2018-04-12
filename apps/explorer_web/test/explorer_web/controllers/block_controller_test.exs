defmodule ExplorerWeb.BlockControllerTest do
  use ExplorerWeb.ConnCase

  describe "GET show/2" do
    test "returns a block", %{conn: conn} do
      block = insert(:block, number: 3)
      conn = get(conn, "/en/blocks/3")
      assert conn.assigns.block.id == block.id
    end
  end

  describe "GET index/2" do
    test "returns all blocks", %{conn: conn} do
      block_ids =
        insert_list(4, :block) |> Enum.map(fn block -> block.number end) |> Enum.reverse()

      conn = get(conn, "/en/blocks")
      assert conn.assigns.blocks |> Enum.map(fn block -> block.number end) == block_ids
    end

    test "returns a block with two transactions", %{conn: conn} do
      block = insert(:block)
      transaction = insert(:transaction)
      insert(:block_transaction, block: block, transaction: transaction)
      other_transaction = insert(:transaction)
      insert(:block_transaction, block: block, transaction: other_transaction)
      conn = get(conn, "/en/blocks")
      assert conn.assigns.blocks.entries |> Enum.count() == 1
    end
  end
end
