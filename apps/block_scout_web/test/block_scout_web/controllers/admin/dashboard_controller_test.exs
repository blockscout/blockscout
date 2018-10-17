defmodule BlockScoutWeb.Admin.DashboardControllerTest do
  use BlockScoutWeb.ConnCase

  alias BlockScoutWeb.Router

  describe "index/2" do
    setup %{conn: conn} do
      admin = insert(:administrator)

      conn =
        conn
        |> bypass_through(Router, [:browser])
        |> get("/")
        |> put_session(:user_id, admin.user.id)
        |> send_resp(200, "")
        |> recycle()

      {:ok, conn: conn}
    end

    test "shows the dashboard page", %{conn: conn} do
      result = get(conn, "/admin" <> AdminRoutes.dashboard_path(conn, :index))
      assert html_response(result, 200) =~ "administrator_dashboard"
    end
  end
end
