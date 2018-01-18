defmodule ExplorerWeb.PageControllerTest do
  use ExplorerWeb.ConnCase

  describe "GET index/2" do
    test "returns a welcome message", %{conn: conn} do
      conn = get conn, "/"
      assert html_response(conn, 200) =~ "Welcome"
    end

    test "returns a block", %{conn: conn} do
      block = insert(:block, %{number: 23})
      conn = get conn, "/"
      assert(List.first(conn.assigns.blocks) == block)
    end

    test "excludes all but the most recent five blocks", %{conn: conn} do
      old_block = insert(:block)
      insert_list(5, :block)
      conn = get conn, "/"
      refute(Enum.member?(conn.assigns.blocks, old_block))
    end
  end
end
