defmodule BlockScoutWeb.MetricsControllerTest do
  use BlockScoutWeb.ConnCase

  describe "/metrics page" do
    test "renders /metrics page", %{conn: conn} do
      conn = get(conn, "/metrics")

      assert text_response(conn, 200)
    end
  end
end
