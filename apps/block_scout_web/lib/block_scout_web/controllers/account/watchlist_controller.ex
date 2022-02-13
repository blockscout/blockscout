defmodule BlockScoutWeb.Account.WatchlistController do
  use BlockScoutWeb, :controller

  alias BlockScoutWeb.Account.AuthController
  alias Explorer.Accounts.Watchlist
  alias Explorer.Repo

  def show(conn, _params) do
    case AuthController.current_user(conn) do
      nil ->
        conn
        |> put_flash(:info, "Sign in to see watchlist!")
        |> redirect(to: root())

      %{} = user ->
        render(
          conn,
          "show.html",
          watchlist: watchlist_with_addresses(user)
        )
    end
  end

  defp watchlist_with_addresses(user) do
    Watchlist
    |> Repo.get(user.watchlist_id)
    |> Repo.preload(watchlist_addresses: :address)
  end

  defp root do
    System.get_env("NETWORK_PATH") || "/"
  end
end
