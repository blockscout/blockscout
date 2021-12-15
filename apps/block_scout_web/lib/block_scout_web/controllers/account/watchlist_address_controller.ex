defmodule BlockScoutWeb.Account.WatchlistAddressController do
  use BlockScoutWeb, :controller

  alias Explorer.Repo
  alias Explorer.Accounts.WatchlistAddress
  alias Explorer.Accounts.WatchlistAddressForm

  def new(conn, _params) do
    render(conn, "new.html", watchlist_address: new_address())
  end

  def create(conn, %{"watchlist_address_form" => wa_params}) do
    case AddWatchlistAddress.call(current_user(conn).watchlist_id, wa_params) do
      {:ok, _watchlist_address} ->
        conn
        # |> put_flash(:info, "Address created!")
        |> redirect(to: watchlist_path(conn, :show))

      {:error, message = message} ->
        conn
        # |> put_flash(:error, message)
        |> render("new.html", watchlist_address: changeset(wa_params))
    end
  end

  def show(conn, _params) do
    case current_user(conn) do
      nil ->
        conn
        # |> put_flash(:info, "Sign in to see watchlist!")
        |> redirect(to: root())

      %{} = user ->
        render(
          conn,
          "show.html",
          watchlist: watchlist(user)
        )
    end
  end

  def edit(conn, %{"id" => id}) do
    wla = get_watchlist_address(id)
    form = WatchlistAddress.to_form(wla)

    changeset = WatchlistAddressForm.changeset(form, %{})

    render(conn, "edit.html", watchlist_address_id: wla, changeset: changeset)
  end

  def update(conn, %{"id" => id, "watchlist_address_form" => wa_params}) do
    wla = get_watchlist_address(id)

    case UpdateWatchlistAddress.call(wla, wa_params) do
      {:ok, _watchlist_address} ->
        conn
        # |> put_flash(:info, "Address updated")
        |> redirect(to: watchlist_path(conn, :show))

      {:error, message = message} ->
        conn
        |> put_flash(:error, message)
        |> render("edit.html", watchlist_address: changeset(wa_params))
    end
  end

  def delete(conn, %{"id" => id}) do
    wla = get_watchlist_address(id)
    Repo.delete(wla)

    conn
    # |> put_flash(:info, "Watchlist Address removed successfully.")
    |> redirect(to: watchlist_path(conn, :show))
  end

  defp changeset(params) do
    WatchlistAddressForm.changeset(%WatchlistAddressForm{}, params)
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

  defp watchlist(user) do
    wl = Repo.get(Watchlist, user.watchlist_id)
    Repo.preload(wl, watchlist_addresses: :address)
  end

  defp get_watchlist_address(id) do
    wla = Repo.get(WatchlistAddress, id)
    Repo.preload(wla, :address)
  end

  defp current_user(conn) do
    get_session(conn, :current_user)
  end

  defp root do
    System.get_env("NETWORK_PATH") || "/"
  end
end
