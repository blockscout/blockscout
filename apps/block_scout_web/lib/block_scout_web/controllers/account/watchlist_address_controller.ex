defmodule BlockScoutWeb.Account.WatchlistAddressController do
  use BlockScoutWeb, :controller

  alias Ecto.Changeset
  alias Explorer.Repo
  alias Explorer.Accounts.{WatchlistAddress, WatchlistAddressForm}

  import BlockScoutWeb.Account.AuthController, only: [authenticate!: 1]

  def new(conn, _params) do
    authenticate!(conn)

    render(conn, "new.html", watchlist_address: new_address())
  end

  def create(conn, %{"watchlist_address_form" => wa_params}) do
    current_user = authenticate!(conn)

    case AddWatchlistAddress.call(current_user.watchlist_id, wa_params) do
      {:ok, _watchlist_address} ->
        conn
        # |> put_flash(:info, "Address created!")
        |> redirect(to: watchlist_path(conn, :show))

      {:error, message = message} ->
        conn
        # |> put_flash(:error, message)
        |> render("new.html", watchlist_address: changeset_with_error(wa_params, message))
    end
  end

  def show(conn, _params) do
    current_user = authenticate!(conn)

    render(
      conn,
      "show.html",
      watchlist: watchlist(current_user)
    )
  end

  def edit(conn, %{"id" => id}) do
    authenticate!(conn)

    case get_watchlist_address!(conn, id) do
      nil ->
        conn
        |> put_status(404)
        |> put_view(BlockScoutWeb.ErrorView)
        |> render(:"404")

      %WatchlistAddress{} = wla ->
        form = WatchlistAddress.to_form(wla)
        changeset = WatchlistAddressForm.changeset(form, %{})

        render(conn, "edit.html", watchlist_address_id: wla, changeset: changeset)
    end
  end

  def update(conn, %{"id" => id, "watchlist_address_form" => wa_params}) do
    authenticate!(conn)

    wla = get_watchlist_address!(conn, id)

    case UpdateWatchlistAddress.call(wla, wa_params) do
      {:ok, _watchlist_address} ->
        conn
        # |> put_flash(:info, "Address updated")
        |> redirect(to: watchlist_path(conn, :show))

      {:error, message = message} ->
        conn
        # |> put_flash(:error, message)
        |> render("edit.html", watchlist_address: changeset_with_error(wa_params, message))
    end
  end

  def delete(conn, %{"id" => id}) do
    authenticate!(conn)

    wla = get_watchlist_address!(conn, id)
    Repo.delete(wla)

    conn
    # |> put_flash(:info, "Watchlist Address removed successfully.")
    |> redirect(to: watchlist_path(conn, :show))
  end

  defp changeset(params) do
    WatchlistAddressForm.changeset(%WatchlistAddressForm{}, params)
  end

  defp changeset_with_error(params, message) do
    %{changeset(params) | action: :insert}
    |> Changeset.add_error(:address_hash, message)
  end

  defp new_address, do: WatchlistAddressForm.changeset(%WatchlistAddressForm{}, %{})

  defp watchlist(user) do
    Watchlist
    |> Repo.get(user.watchlist_id)
    |> Repo.preload(watchlist_addresses: :address)
  end

  defp get_watchlist_address!(conn, id) do
    WatchlistAddress
    |> Repo.get_by(id: id, watchlist_id: authenticate!(conn).watchlist_id)
    |> Repo.preload(:address)
  end
end
