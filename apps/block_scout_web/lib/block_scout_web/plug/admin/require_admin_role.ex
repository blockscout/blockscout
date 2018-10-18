defmodule BlockScoutWeb.Plug.Admin.RequireAdminRole do
  @moduledoc """
  Authorization plug requiring a user to be authenticated and have an admin role.
  """

  import Plug.Conn

  import Phoenix.Controller, only: [redirect: 2]

  alias BlockScoutWeb.AdminRouter.Helpers, as: AdminRoutes
  alias Explorer.Admin

  def init(opts), do: opts

  def call(conn, _) do
    with user when not is_nil(user) <- conn.assigns[:user],
         {:ok, admin} <- Admin.from_user(user) do
      assign(conn, :admin, admin)
    else
      _ ->
        conn
        |> redirect(to: AdminRoutes.session_path(conn, :new))
        |> halt()
    end
  end
end
