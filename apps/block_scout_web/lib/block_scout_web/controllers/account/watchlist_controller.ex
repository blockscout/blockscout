defmodule BlockScoutWeb.Account.WatchlistController do
  use BlockScoutWeb, :controller

  import BlockScoutWeb.Account.AuthController, only: [authenticate!: 1]
  import Ecto.Query, only: [from: 2]

  alias Explorer.Account.{Watchlist, WatchlistAddress}
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
    |> Repo.account_repo().get(user.watchlist_id)
    |> Repo.account_repo().preload(watchlist_addresses: from(wa in WatchlistAddress, order_by: [desc: wa.id]))
    |> WatchlistAddress.preload_address_fetched_coin_balance()
  end
end
