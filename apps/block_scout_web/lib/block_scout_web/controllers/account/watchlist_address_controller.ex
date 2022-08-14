defmodule BlockScoutWeb.Account.WatchlistAddressController do
  use BlockScoutWeb, :controller

  alias Explorer.Account.WatchlistAddress

  import BlockScoutWeb.Account.AuthController, only: [authenticate!: 1]

  def new(conn, _params) do
    authenticate!(conn)

    render(conn, "form.html", method: :create, watchlist_address: empty_watchlist_address())
  end

  def create(conn, %{"watchlist_address" => wa_params}) do
    current_user = authenticate!(conn)

    case WatchlistAddress.create(params_to_attributes(wa_params, current_user.watchlist_id)) do
      {:ok, _watchlist_address} ->
        redirect(conn, to: watchlist_path(conn, :show))

      {:error, changeset} ->
        render(conn, "form.html", method: :create, watchlist_address: changeset)
    end
  end

  def edit(conn, %{"id" => id}) do
    current_user = authenticate!(conn)

    case WatchlistAddress.get_watchlist_address_by_id_and_watchlist_id(id, current_user.watchlist_id) do
      nil ->
        not_found(conn)

      %WatchlistAddress{} = watchlist_address ->
        render(conn, "form.html", method: :update, watchlist_address: WatchlistAddress.changeset(watchlist_address))
    end
  end

  def update(conn, %{"id" => id, "watchlist_address" => wa_params}) do
    current_user = authenticate!(conn)

    case wa_params
         |> params_to_attributes(current_user.watchlist_id)
         |> Map.put(:id, id)
         |> WatchlistAddress.update() do
      {:ok, _watchlist_address} ->
        redirect(conn, to: watchlist_path(conn, :show))

      {:error, changeset} ->
        render(conn, "form.html", method: :update, watchlist_address: changeset)
    end
  end

  def delete(conn, %{"id" => id}) do
    current_user = authenticate!(conn)

    WatchlistAddress.delete(id, current_user.watchlist_id)

    redirect(conn, to: watchlist_path(conn, :show))
  end

  defp empty_watchlist_address, do: WatchlistAddress.changeset()

  defp params_to_attributes(
         %{
           "address_hash" => address_hash,
           "name" => name,
           "watch_coin_input" => watch_coin_input,
           "watch_coin_output" => watch_coin_output,
           "watch_erc_20_input" => watch_erc_20_input,
           "watch_erc_20_output" => watch_erc_20_output,
           "watch_erc_721_input" => watch_nft_input,
           "watch_erc_721_output" => watch_nft_output,
           "notify_email" => notify_email
         },
         watchlist_id
       ) do
    %{
      address_hash: address_hash,
      name: name,
      watch_coin_input: watch_coin_input,
      watch_coin_output: watch_coin_output,
      watch_erc_20_input: watch_erc_20_input,
      watch_erc_20_output: watch_erc_20_output,
      watch_erc_721_input: watch_nft_input,
      watch_erc_721_output: watch_nft_output,
      watch_erc_1155_input: watch_nft_input,
      watch_erc_1155_output: watch_nft_output,
      notify_email: notify_email,
      watchlist_id: watchlist_id
    }
  end
end
