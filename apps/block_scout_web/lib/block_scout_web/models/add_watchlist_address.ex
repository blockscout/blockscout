defmodule AddWatchlistAddress do
  @moduledoc """
  Create watchlist address, associated with Address and Watchlist

  params =  %{
    "address_hash_string" => "0xBA80A39FD165DFD3BFE704EFAB40B7F899DA7C4B",
    "name" => "wallet"
  }
  call(watchlist, params)
  """

  alias Explorer.Accounts.Notifier.ForbiddenAddress
  alias Explorer.Accounts.{Watchlist, WatchlistAddress}
  alias Explorer.Chain.Address
  alias Explorer.Repo

  def call(watchlist_id, %{"address_hash" => address_hash_string} = params) do
    case ForbiddenAddress.check(address_hash_string) do
      {:ok, address_hash} ->
        try_create_watchlist_address(watchlist_id, address_hash, params)

      {:error, message} ->
        {:error, message}
    end
  end

  defp try_create_watchlist_address(watchlist_id, address_hash, params) do
    case find_watchlist_address(watchlist_id, address_hash) do
      %WatchlistAddress{} ->
        {:error, "Address already added to the watchlist"}

      nil ->
        with {:ok, %Address{} = address} <- find_or_create_address(address_hash) do
          address
          |> params_to_attributes(params)
          |> build_watchlist_address(watchlist(watchlist_id))
          |> Repo.insert()
        end
    end
  end

  defp params_to_attributes(
         address,
         %{
           "name" => name,
           "watch_coin_input" => watch_coin_input,
           "watch_coin_output" => watch_coin_output,
           "watch_erc_20_input" => watch_erc_20_input,
           "watch_erc_20_output" => watch_erc_20_output,
           "watch_nft_input" => watch_nft_input,
           "watch_nft_output" => watch_nft_output,
           "notify_email" => notify_email
         }
       ) do
    %{
      address_hash: address.hash,
      name: name,
      watch_coin_input: to_bool(watch_coin_input),
      watch_coin_output: to_bool(watch_coin_output),
      watch_erc_20_input: to_bool(watch_erc_20_input),
      watch_erc_20_output: to_bool(watch_erc_20_output),
      watch_erc_721_input: to_bool(watch_nft_input),
      watch_erc_721_output: to_bool(watch_nft_output),
      watch_erc_1155_input: to_bool(watch_nft_input),
      watch_erc_1155_output: to_bool(watch_nft_output),
      notify_email: to_bool(notify_email)
    }
  end

  defp to_bool("true"), do: true
  defp to_bool("false"), do: false
  defp to_bool(bool), do: bool

  defp find_watchlist_address(watchlist_id, address_hash) do
    Repo.get_by(WatchlistAddress,
      address_hash: address_hash,
      watchlist_id: watchlist_id
    )
  end

  defp find_or_create_address(address_hash) do
    with {:error, :address_not_found} <- find_address(address_hash),
         do: create_address(address_hash)
  end

  defp create_address(address_hash) do
    with {:error, _} <- Repo.insert(%Address{hash: address_hash}),
         do: {:error, :wrong_address}
  end

  defp find_address(address_hash) do
    case Repo.get(Address, address_hash) do
      nil -> {:error, :address_not_found}
      %Address{} = address -> {:ok, address}
    end
  end

  defp build_watchlist_address(attributes, watchlist) do
    Ecto.build_assoc(
      watchlist,
      :watchlist_addresses,
      attributes
    )
  end

  defp watchlist(watchlist_id) do
    Repo.get(Watchlist, watchlist_id)
  end
end
