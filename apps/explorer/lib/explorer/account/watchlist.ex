defmodule Explorer.Account.Watchlist do
  @moduledoc """
    Watchlist is root entity for WatchlistAddresses
  """

  use Explorer.Schema

  import Ecto.Changeset

  alias Ecto.Multi
  alias Explorer.Account.{Identity, WatchlistAddress}

  @derive {Jason.Encoder, only: [:name, :watchlist_addresses]}
  typed_schema "account_watchlists" do
    field(:name, :string, null: false)
    belongs_to(:identity, Identity)
    has_many(:watchlist_addresses, WatchlistAddress)

    timestamps()
  end

  @doc false
  def changeset(watchlist, attrs) do
    watchlist
    |> cast(attrs, [:name])
    |> validate_required([:name])
  end

  def acquire_for_merge(multi, primary_id, ids_to_merge) do
    multi
    |> Multi.run(:acquire_primary_watchlist, fn repo, _ ->
      {:ok, repo.all(from(watchlist in __MODULE__, where: watchlist.identity_id == ^primary_id))}
    end)
    |> Multi.run(:acquire_watchlists_to_merge, fn repo, _ ->
      {:ok, repo.all(from(watchlist in __MODULE__, where: watchlist.identity_id in ^ids_to_merge))}
    end)
  end
end
