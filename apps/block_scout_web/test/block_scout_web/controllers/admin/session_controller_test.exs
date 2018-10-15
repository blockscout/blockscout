defmodule BlockScoutWeb.Admin.SessionControllerTest do
  use BlockScoutWeb.ConnCase

  setup %{conn: conn} do
    conn =
      conn
      |> bypass_through()
      |> get("/")

    {:ok, conn: conn}
  end

  describe "new/2" do
    test "redirects to setup page if not configured", %{conn: conn} do
      result = get(conn, AdminRoutes.session_path(conn, :new))
      assert redirected_to(result) == AdminRoutes.setup_path(conn, :configure)
    end

    test "shows the admin login page", %{conn: conn} do
      insert(:administrator)
      result = get(conn, AdminRoutes.session_path(conn, :new))
      assert html_response(result, 200) =~ "administrator_login"
    end
  end

  describe "create/2" do
    test "redirects to setup page if not configured", %{conn: conn} do
      result = post(conn, AdminRoutes.session_path(conn, :create), %{})
      assert redirected_to(result) == AdminRoutes.setup_path(conn, :configure)
    end

    test "redirects to dashboard on successful admin login", %{conn: conn} do
      admin = insert(:administrator)

      params = %{
        "authenticate" => %{
          username: admin.user.username,
          password: "password"
        }
      }

      result = post(conn, AdminRoutes.session_path(conn, :create), params)
      assert redirected_to(result) == AdminRoutes.dashboard_path(conn, :index)
    end

    test "reshows form if params are invalid", %{conn: conn} do
      insert(:administrator)
      params = %{"authenticate" => %{}}

      result = post(conn, AdminRoutes.session_path(conn, :create), params)
      assert html_response(result, 200) =~ "administrator_login"
    end

    test "reshows form if credentials are invalid", %{conn: conn} do
      admin = insert(:administrator)

      params = %{
        "authenticate" => %{
          username: admin.user.username,
          password: "badpassword"
        }
      }

      result = post(conn, AdminRoutes.session_path(conn, :create), params)
      assert html_response(result, 200) =~ "administrator_login"
    end

    test "reshows form if user is not an admin", %{conn: conn} do
      insert(:administrator)
      user = insert(:user)

      params = %{
        "authenticate" => %{
          username: user.username,
          password: "password"
        }
      }

      result = post(conn, AdminRoutes.session_path(conn, :create), params)
      assert html_response(result, 200) =~ "administrator_login"
    end
  end
end
