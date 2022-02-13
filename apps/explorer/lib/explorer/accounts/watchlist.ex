defmodule Explorer.Accounts.Watchlist do
  @moduledoc """
    Watchlist is root entity for WatchlistAddresses
  """

  use Ecto.Schema
  import Ecto.Changeset
  alias Explorer.Accounts.{Identity, WatchlistAddress}

  schema "account_watchlists" do
    field(:name, :string)
    belongs_to(:identity, Identity)
    has_many(:watchlist_addresses, WatchlistAddress)
    has_many(:addresses, through: [:watchlist_addresses, :address])

    timestamps()
  end

  @doc false
  def changeset(watchlist, attrs) do
    watchlist
    |> cast(attrs, [:name])
    |> validate_required([:name])
  end
end
