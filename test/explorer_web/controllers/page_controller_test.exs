defmodule ExplorerWeb.PageControllerTest do
  use ExplorerWeb.ConnCase

  describe "GET index/2 without a locale" do
    test "redirects to the en locale", %{conn: conn} do
      conn = get conn, "/"
      assert redirected_to(conn) == "/en"
    end
  end

  describe "GET index/2 with a locale" do
    test "returns a welcome message", %{conn: conn} do
      conn = get conn, "/en"
      assert html_response(conn, 200) =~ "Welcome"
    end

    test "returns a block", %{conn: conn} do
      insert(:block, %{number: 23})
      conn = get conn, "/en"
      assert(List.first(conn.assigns.blocks).number == 23)
    end

    test "excludes all but the most recent five blocks", %{conn: conn} do
      old_block = insert(:block)
      insert_list(5, :block)
      conn = get conn, "/en"
      refute(Enum.member?(conn.assigns.blocks, old_block))
    end
  end
end
