defmodule BlockScoutWeb.AuthController do
  use BlockScoutWeb, :controller

  plug(Ueberauth)

  def logout(conn, _params) do
    conn
    |> put_flash(:info, "You have been logged out!")
    |> configure_session(drop: true)
    |> redirect(to: "/")
  end

  def profile(conn, _params) do
    case get_session(conn, :current_user) do
      nil ->
        conn
        |> put_flash(:info, "You must sign in to view profile!")
        |> redirect(to: "/")

      %{} = user ->
        conn
        |> put_flash(:info, "You are signed in as " <> user.name <> ".")
        |> render(:profile, user: user)
    end
  end

  def callback(%{assigns: %{ueberauth_failure: _fails}} = conn, _params) do
    conn
    |> put_flash(:error, "Failed to authenticate.")
    |> redirect(to: "/")
  end

  def callback(%{assigns: %{ueberauth_auth: auth}} = conn, _params) do
    case UserFromAuth.find_or_create(auth) do
      {:ok, user} ->
        conn
        |> put_flash(:info, "Successfully authenticated as " <> user.name <> ".")
        |> put_session(:current_user, user)
        |> redirect(to: "/")

      {:error, reason} ->
        conn
        |> put_flash(:error, reason)
        |> redirect(to: "/")
    end
  end
end
