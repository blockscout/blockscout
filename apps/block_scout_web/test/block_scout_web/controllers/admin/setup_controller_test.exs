defmodule BlockScoutWeb.Admin.SetupControllerTest do
  use BlockScoutWeb.ConnCase

  alias BlockScoutWeb.Admin.SetupController
  alias Explorer.Admin

  setup %{conn: conn} do
    conn =
      conn
      |> bypass_through()
      |> get("/")

    {:ok, conn: conn}
  end

  describe "configure/2" do
    test "redirects to session page if already configured", %{conn: conn} do
      insert(:administrator)
      result = get(conn, AdminRoutes.setup_path(conn, :configure))
      assert redirected_to(result) == AdminRoutes.session_path(conn, :new)
    end
  end

  describe "configure/2 with no params" do
    test "shows the verification page", %{conn: conn} do
      result = get(conn, AdminRoutes.setup_path(conn, :configure))
      assert html_response(result, 200) =~ "administrator_verify"
    end
  end

  describe "configure/2 with state param" do
    test "shows verification page when state is invalid", %{conn: conn} do
      result = get(conn, AdminRoutes.setup_path(conn, :configure), %{state: ""})
      assert html_response(result, 200) =~ "administrator_verify"
    end

    test "shows registration page when state is valid", %{conn: conn} do
      state = SetupController.generate_secure_token()
      result = get(conn, AdminRoutes.setup_path(conn, :configure), %{state: state})
      assert html_response(result, 200) =~ "administrator_registration"
    end
  end

  describe "configure_admin/2" do
    test "redirects to session page if already configured", %{conn: conn} do
      insert(:administrator)
      result = post(conn, AdminRoutes.setup_path(conn, :configure), %{})
      assert redirected_to(result) == AdminRoutes.session_path(conn, :new)
    end
  end

  describe "configure_admin/2 with no params" do
    test "reshows the verification page", %{conn: conn} do
      result = post(conn, AdminRoutes.setup_path(conn, :configure_admin), %{})
      assert html_response(result, 200) =~ "administrator_verify"
    end
  end

  describe "configure_admin/2 with verify param" do
    test "redirects with valid recovery key", %{conn: conn} do
      key = Admin.recovery_key()
      params = %{verify: %{recovery_key: key}}
      result = post(conn, AdminRoutes.setup_path(conn, :configure_admin), params)
      assert redirected_to(result) =~ AdminRoutes.setup_path(conn, :configure, %{state: ""})
    end

    test "reshows the verification page with invalid key", %{conn: conn} do
      params = %{verify: %{recovery_key: "bad_key"}}
      result = post(conn, AdminRoutes.setup_path(conn, :configure_admin), params)
      assert html_response(result, 200) =~ "administrator_verify"
    end
  end

  describe "configure_admin with state and registration params" do
    setup do
      [state: SetupController.generate_secure_token()]
    end

    test "reshows the verification page when state is invalid", %{conn: conn} do
      params = %{state: "invalid_state", registration: %{}}
      result = post(conn, AdminRoutes.setup_path(conn, :configure_admin), params)
      assert html_response(result, 200) =~ "administrator_verify"
    end

    test "reshows the registration page when registration is invalid", %{conn: conn, state: state} do
      params = %{state: state, registration: %{}}
      result = post(conn, AdminRoutes.setup_path(conn, :configure_admin), params)
      response = html_response(result, 200)
      assert response =~ "administrator_registration"
      assert response =~ "invalid-feedback"
      assert response =~ "is-invalid"
    end

    test "redirects to dashboard when state and registration are valid", %{conn: conn, state: state} do
      params = %{
        state: state,
        registration: %{
          username: "admin_user",
          email: "admin_user@blockscout",
          password: "testpassword",
          password_confirmation: "testpassword"
        }
      }

      result = post(conn, AdminRoutes.setup_path(conn, :configure_admin), params)
      assert redirected_to(result) == AdminRoutes.dashboard_path(conn, :index)
    end
  end
end
