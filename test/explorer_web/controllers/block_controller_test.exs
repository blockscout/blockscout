defmodule ExplorerWeb.BlockControllerTest do
  use ExplorerWeb.ConnCase

  describe "GET show/3" do
    test "returns a block", %{conn: conn} do
      insert(:block, id: 3)
      conn = get(conn, "/en/blocks/3")
      assert conn.assigns.block.id == 3
    end
  end
end
