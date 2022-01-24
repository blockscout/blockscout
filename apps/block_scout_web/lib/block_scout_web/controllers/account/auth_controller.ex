defmodule BlockScoutWeb.Account.AuthController do
  use BlockScoutWeb, :controller

  plug(Ueberauth)

  def logout(conn, _params) do
    conn
    # |> put_flash(:info, "You have been logged out!")
    |> configure_session(drop: true)
    |> redirect(to: root())
  end

  def profile(conn, _params) do
    case get_session(conn, :current_user) do
      nil ->
        conn
        # |> put_flash(:info, "You must sign in to view profile!")
        |> redirect(to: root())

      %{} = user ->
        conn
        |> render(:profile, user: user)
    end
  end

  def callback(%{assigns: %{ueberauth_failure: _fails}} = conn, _params) do
    conn
    |> put_flash(:error, "Failed to authenticate.")
    |> redirect(to: root())
  end

  def callback(%{assigns: %{ueberauth_auth: auth}} = conn, _params) do
    case UserFromAuth.find_or_create(auth) do
      {:ok, user} ->
        conn
        # |> put_flash(:info, "Successfully authenticated as " <> user.name <> ".")
        |> put_session(:current_user, user)
        |> redirect(to: root())

      {:error, reason} ->
        conn
        |> put_flash(:error, reason)
        |> redirect(to: root())
    end
  end

  # for importing in other controllers
  def authenticate!(conn) do
    current_user(conn) || redirect(conn, to: root())
  end

  def current_user(conn) do
    session = Map.has_key?(conn.private, :plug_session) && conn.private.plug_session

    if session && Map.has_key?(session, "current_user") do
      get_session(conn, :current_user)
    else
      nil
    end
  end

  defp root do
    System.get_env("NETWORK_PATH") || "/"
  end
end
