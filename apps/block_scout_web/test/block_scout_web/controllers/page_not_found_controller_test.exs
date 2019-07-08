defmodule BlockScoutWeb.PageNotFoundControllerTest do
  use BlockScoutWeb.ConnCase

  describe "GET index/2" do
    test "returns 404 status", %{conn: conn} do
      conn = get(conn, "/wrong", %{})

      assert html_response(conn, 404)
    end
  end
end
