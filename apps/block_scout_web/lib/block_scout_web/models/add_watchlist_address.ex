defmodule AddWatchlistAddress do
  @moduledoc """
  Create watchlist address, associated with Address and Watchlist

  params =  %{
    "address_hash" => "0xBA80A39FD165DFD3BFE704EFAB40B7F899DA7C4B",
    "name" => "wallet"
  }
  call(watchlist, params)
  """

  alias Explorer.Repo
  alias Explorer.Accounts.Watchlist
  alias Explorer.Chain.Address

  def call(watchlist_id, params) do
    %{"address_hash" => address_hash} = params

    case find_address(address_hash) do
      {:ok, address} ->
        address
        |> params_to_attributes(params)
        |> build_watchlist_address(watchlist(watchlist_id))
        |> Repo.insert()

      {:error, message} ->
        {:error, message}
    end
  end

  defp params_to_attributes(address, params) do
    %{
      "name" => name,
      "watch_coin_input" => watch_coin_input,
      "watch_coin_output" => watch_coin_output,
      "watch_erc_20_input" => watch_erc_20_input,
      "watch_erc_20_output" => watch_erc_20_output,
      "watch_erc_721_input" => watch_erc_721_input,
      "watch_erc_721_output" => watch_erc_721_output,
      "watch_erc_1155_input" => watch_erc_1155_input,
      "watch_erc_1155_output" => watch_erc_1155_output,
      "notify_email" => notify_email,
      "notify_feed" => notify_feed
    } = params

    %{
      address_hash: address.hash,
      name: name,
      watch_coin_input: to_bool(watch_coin_input),
      watch_coin_output: to_bool(watch_coin_output),
      watch_erc_20_input: to_bool(watch_erc_20_input),
      watch_erc_20_output: to_bool(watch_erc_20_output),
      watch_erc_721_input: to_bool(watch_erc_721_input),
      watch_erc_721_output: to_bool(watch_erc_721_output),
      watch_erc_1155_input: to_bool(watch_erc_1155_input),
      watch_erc_1155_output: to_bool(watch_erc_1155_output),
      notify_email: to_bool(notify_email),
      notify_feed: to_bool(notify_feed)
    }
  end

  defp to_bool("true"), do: true
  defp to_bool("false"), do: false

  defp find_address(address_hash) do
    try do
      case Repo.get(Address, address_hash) do
        nil -> {:error, :address_not_found}
        %{} = address -> {:ok, address}
      end
    rescue
      _ ->
        {:error, :invalid_address}
    end
  end

  defp build_watchlist_address(attributes, watchlist) do
    Ecto.build_assoc(
      watchlist,
      :watchlist_addresses,
      attributes
      # %{address_hash: address.hash, name: name}
    )
  end

  defp watchlist(watchlist_id) do
    Repo.get(Watchlist, watchlist_id)
  end
end
