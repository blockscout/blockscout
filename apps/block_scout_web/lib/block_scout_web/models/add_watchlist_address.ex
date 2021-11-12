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
    %{"address_hash" => address_hash, "name" => name} = params

    case find_address(address_hash) do
      {:ok, address} ->
        address
        |> build_watchlist_address(watchlist(watchlist_id), name)
        |> Repo.insert()

      {:error, message} ->
        {:error, message}
    end
  end

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

  defp build_watchlist_address(address, watchlist, name) do
    Ecto.build_assoc(
      watchlist,
      :watchlist_addresses,
      %{address_hash: address.hash, name: name}
    )
  end

  defp watchlist(watchlist_id) do
    Repo.get(Watchlist, watchlist_id)
  end
end
