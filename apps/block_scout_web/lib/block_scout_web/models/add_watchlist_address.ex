defmodule AddWatchlistAddress do
  @moduledoc """
  Create watchlist address, associated with Address and Watchlist

  params =  %{
    "address_hash_string" => "0xBA80A39FD165DFD3BFE704EFAB40B7F899DA7C4B",
    "name" => "wallet"
  }
  call(watchlist, params)
  """

  alias Explorer.Repo
  alias Explorer.Accounts.Watchlist
  alias Explorer.Chain
  alias Explorer.Chain.Address

  def call(watchlist_id, params) do
    %{"address_hash" => address_hash_string} = params

    case format_address(address_hash_string) do
      {:ok, address_hash} ->
        address_hash
        |> find_or_create_address()
        |> params_to_attributes(params)
        |> build_watchlist_address(watchlist(watchlist_id))
        |> Repo.insert()

      :error ->
        {:error, "Wrong address"}
    end
  end

  defp params_to_attributes(address, params) do
    %{
      "name" => name,
      "watch_coin_input" => watch_coin_input,
      "watch_coin_output" => watch_coin_output,
      "watch_erc_20_input" => watch_erc_20_input,
      "watch_erc_20_output" => watch_erc_20_output,
      "watch_nft_input" => watch_nft_input,
      "watch_nft_output" => watch_nft_output,
      "notify_email" => notify_email
    } = params

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

  def format_address(address_hash_string) do
    Chain.string_to_address_hash(address_hash_string)
  end

  def find_or_create_address(address_hash) do
    case find_address(address_hash) do
      {:ok, address} -> address
      {:error, :address_not_found} -> create_address(address_hash)
    end
  end

  def create_address(address_hash) do
    case Repo.insert(%Address{hash: address_hash}) do
      {:ok, address} -> address
      {:error, _} -> :wrong_address
    end
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
      # %{address_hash: address.hash, name: name}
    )
  end

  defp watchlist(watchlist_id) do
    Repo.get(Watchlist, watchlist_id)
  end
end
