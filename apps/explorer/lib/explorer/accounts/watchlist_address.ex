defmodule Explorer.Accounts.WatchlistAddress do
  use Ecto.Schema
  import Ecto.Changeset

  alias Explorer.Accounts.Watchlist
  alias Explorer.Chain.Address
  alias Explorer.Chain.Hash

  schema "account_watchlist_addresses" do
    field :name, :string
    belongs_to(:address, Address, foreign_key: :address_hash, references: :hash, type: Hash.Address)
    belongs_to(:watchlist, Watchlist)

    timestamps()
  end

  @doc false
  def changeset(watchlist_address, attrs) do
    watchlist_address
    |> cast(attrs, [:name, :address_hash])
    |> validate_required([:name, :address_hash])
  end
end
