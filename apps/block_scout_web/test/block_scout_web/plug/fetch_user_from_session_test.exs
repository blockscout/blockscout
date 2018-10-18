defmodule BlockScoutWeb.Plug.FetchUserFromSessionTest do
  use BlockScoutWeb.ConnCase

  import Plug.Conn, only: [put_session: 3]

  alias BlockScoutWeb.Plug.FetchUserFromSession
  alias BlockScoutWeb.Router
  alias Explorer.Accounts.User

  test "init/1" do
    assert FetchUserFromSession.init([]) == []
  end

  describe "call/2" do
    setup %{conn: conn} do
      conn =
        conn
        |> bypass_through(Router, [:browser])
        |> get("/")

      {:ok, conn: conn}
    end

    test "loads user if valid user id in session", %{conn: conn} do
      user = insert(:user)

      result =
        conn
        |> put_session(:user_id, user.id)
        |> FetchUserFromSession.call([])

      assert %User{} = result.assigns.user
    end

    test "returns conn if user id is invalid in session", %{conn: conn} do
      conn = put_session(conn, :user_id, 1)
      result = FetchUserFromSession.call(conn, [])

      assert conn == result
    end

    test "returns conn if no user id is in session", %{conn: conn} do
      assert FetchUserFromSession.call(conn, []) == conn
    end
  end
end
