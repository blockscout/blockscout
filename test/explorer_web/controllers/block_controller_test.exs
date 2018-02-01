defmodule ExplorerWeb.BlockControllerTest do
  use ExplorerWeb.ConnCase

  describe "GET show/3" do
    test "returns a block", %{conn: conn} do
      block = insert(:block, number: 3)
      conn = get(conn, "/en/blocks/3")
      assert conn.assigns.block.id == block.id
    end
  end
end
