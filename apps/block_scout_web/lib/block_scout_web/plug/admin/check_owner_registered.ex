defmodule BlockScoutWeb.Plug.Admin.CheckOwnerRegistered do
  @moduledoc """
  Checks that an admin owner has registered.

  If the admin owner, the user is redirected to a page
  with instructions of how to continue setup.
  """

  import Phoenix.Controller, only: [redirect: 2]
  import Plug.Conn

  alias BlockScoutWeb.AdminRouter.Helpers, as: AdminRoutes
  alias Explorer.Admin
  alias Plug.Conn

  def init(opts), do: opts

  def call(%Conn{} = conn, _opts) do
    case Admin.owner() do
      {:ok, _} ->
        conn

      {:error, :not_found} ->
        conn
        |> redirect(to: AdminRoutes.setup_path(conn, :configure))
        |> halt()
    end
  end
end
