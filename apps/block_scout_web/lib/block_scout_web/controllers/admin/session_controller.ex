defmodule BlockScoutWeb.Admin.SessionController do
  use BlockScoutWeb, :controller

  alias Ecto.Changeset
  alias Explorer.{Accounts, Admin}
  alias Explorer.Accounts.User.Authenticate

  def new(conn, _) do
    changeset = Authenticate.changeset()
    render(conn, "login_form.html", changeset: changeset)
  end

  def create(conn, %{"authenticate" => params}) do
    with {:user, {:ok, user}} <- {:user, Accounts.authenticate(params)},
         {:admin, {:ok, _}} <- {:admin, Admin.from_user(user)} do
      conn
      |> put_session(:user_id, user.id)
      |> redirect(to: AdminRoutes.dashboard_path(conn, :index))
    else
      {:user, {:error, :invalid_credentials}} ->
        changeset = Authenticate.changeset(params)
        render(conn, "login_form.html", changeset: changeset)

      {:user, {:error, %Changeset{} = changeset}} ->
        render(conn, "login_form.html", changeset: changeset)

      {:admin, {:error, :not_found}} ->
        changeset = Authenticate.changeset()
        render(conn, "login_form.html", changeset: changeset)
    end
  end

  def create(conn, _) do
    changeset = Authenticate.changeset()
    render(conn, "login_form.html", changeset: changeset)
  end
end
