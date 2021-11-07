defmodule BlockScoutWeb.Account.WatchlistController do
  use BlockScoutWeb, :controller

  alias Explorer.Repo
  alias Explorer.Accounts.Watchlist

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
          watchlist: Repo.get(Watchlist, user.watchlist_id)
        )
    end
  end

  defp current_user(conn) do
    get_session(conn, :current_user)
  end

  defp root do
    System.get_env("NETWORK_PATH") || "/"
  end
end
