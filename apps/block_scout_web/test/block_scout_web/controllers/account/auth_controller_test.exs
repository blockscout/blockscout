defmodule BlockScoutWeb.Account.AuthControllerTest do
  use BlockScoutWeb.ConnCase

  alias Explorer.Account.Identity
  alias Explorer.Repo

  setup %{conn: conn} do
    auth = %Ueberauth.Auth{
      info: %Ueberauth.Auth.Info{
        email: "test@example.com",
        nickname: "old_nickname"
      },
      provider: :auth0,
      uid: "auth0|123"
    }

    {:ok, user} = Identity.find_or_create(auth)

    # Initialize session with current_user
    conn = 
      conn
      |> Plug.Test.init_test_session(current_user: user)
      |> fetch_flash()

    {:ok, user: user, conn: conn}
  end

  describe "PATCH /account/settings/nickname" do
    test "updates nickname and redirects on valid input", %{conn: conn} do
      conn = patch(conn, "/account/settings/nickname", %{"identity" => %{"nickname" => "new_nickname"}})

      assert redirected_to(conn) == "/account/auth/profile"
      assert get_flash(conn, :info) == "Nickname updated successfully"

      # Verify DB update
      user_in_db = Repo.account_repo().one(Identity)
      assert user_in_db.nickname == "new_nickname"

      # Verify session update (must be a map, not a struct)
      updated_user = get_session(conn, :current_user)
      assert is_map(updated_user)
      refute is_struct(updated_user)
      assert updated_user.nickname == "new_nickname"
    end

    test "re-renders form with errors on invalid input", %{conn: conn} do
      conn = patch(conn, "/account/settings/nickname", %{"identity" => %{"nickname" => "ab"}})

      assert html_response(conn, 200) =~ "Profile"
      assert html_response(conn, 200) =~ "should be at least 3 character(s)"
    end
  end
end
