defmodule BlockScoutWeb.Account.WatchlistController do
  use BlockScoutWeb, :controller

  import BlockScoutWeb.Account.AuthController, only: [authenticate!: 1]

  alias Explorer.Account.Watchlist
  alias Explorer.Repo

  def show(conn, _params) do
    current_user = authenticate!(conn)

    render(
      conn,
      "show.html",
      watchlist: watchlist_with_addresses(current_user)
    )
  end

  defp watchlist_with_addresses(user) do
    Watchlist
    |> Repo.get(user.watchlist_id)
    |> Repo.preload(watchlist_addresses: :address)
  end
end
