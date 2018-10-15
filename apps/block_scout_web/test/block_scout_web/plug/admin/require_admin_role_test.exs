defmodule BlockScoutWeb.Plug.Admin.RequireAdminRoleTest do
  use BlockScoutWeb.ConnCase

  import Plug.Conn, only: [put_session: 3, assign: 3]

  alias BlockScoutWeb.Router
  alias BlockScoutWeb.Plug.Admin.RequireAdminRole

  test "init/1" do
    assert RequireAdminRole.init([]) == []
  end

  describe "call/2" do
    setup %{conn: conn} do
      conn =
        conn
        |> bypass_through(Router, [:browser])
        |> get("/")

      {:ok, conn: conn}
    end

    test "redirects if user in conn isn't an admin", %{conn: conn} do
      result = RequireAdminRole.call(conn, [])
      assert redirected_to(result) == AdminRoutes.session_path(conn, :new)
      assert result.halted
    end

    test "continues if user in assigns is an admin", %{conn: conn} do
      administrator = insert(:administrator)

      result =
        conn
        |> put_session(:user_id, administrator.user.id)
        |> assign(:user, administrator.user)
        |> RequireAdminRole.call([])

      refute result.halted
      assert result.state == :unset
    end
  end
end
