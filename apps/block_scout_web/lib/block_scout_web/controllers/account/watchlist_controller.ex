defmodule BlockScoutWeb.Account.WatchlistController do
  use BlockScoutWeb, :controller

  import BlockScoutWeb.Account.AuthController, only: [current_user: 1]

  alias Explorer.Accounts.Watchlist
  alias Explorer.Repo

  def show(conn, _params) do
    case current_user(conn) do
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
