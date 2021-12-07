defmodule BlockScoutWeb.Account.WatchlistController do
  use BlockScoutWeb, :controller

  alias Explorer.Repo
  alias Explorer.Accounts.Watchlist
  alias Explorer.Accounts.WatchlistAddressForm

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
          watchlist: watchlist_with_addresses(user),
          watchlist_address: new_address()
        )
    end
  end

  defp watchlist_with_addresses(user) do
    wl = Repo.get(Watchlist, user.watchlist_id)
    Repo.preload(wl, watchlist_addresses: :address)
  end

  defp new_address do
    WatchlistAddressForm.changeset(
      %WatchlistAddressForm{
        watch_coin_input: true,
        watch_coin_output: true,
        watch_erc_20_input: true,
        watch_erc_20_output: true,
        watch_nft_input: true,
        watch_nft_output: true,
        notify_email: true
      },
      %{}
    )
  end

  defp current_user(conn) do
    get_session(conn, :current_user)
  end

  defp root do
    System.get_env("NETWORK_PATH") || "/"
  end
end
