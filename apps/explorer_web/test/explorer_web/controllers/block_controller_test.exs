defmodule ExplorerWeb.BlockControllerTest do
  use ExplorerWeb.ConnCase

  @locale "en"

  describe "GET show/2" do
    test "with block redirects to block transactions route", %{conn: conn} do
      insert(:block, number: 3)
      conn = get(conn, "/en/blocks/3")
      assert redirected_to(conn) =~ "/en/blocks/3/transactions"
    end
  end

  describe "GET index/2" do
    test "returns all blocks", %{conn: conn} do
      block_ids =
        4
        |> insert_list(:block)
        |> Stream.map(fn block -> block.number end)
        |> Enum.reverse()

      conn = get(conn, block_path(conn, :index, @locale))

      assert conn.assigns.blocks |> Enum.map(fn block -> block.number end) == block_ids
    end

    test "returns a block with two transactions", %{conn: conn} do
      block = insert(:block)

      2
      |> insert_list(:transaction)
      |> with_block(block)

      conn = get(conn, block_path(conn, :index, @locale))

      assert conn.assigns.blocks.entries |> Enum.count() == 1
    end
  end
end
