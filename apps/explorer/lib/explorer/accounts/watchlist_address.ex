defmodule Explorer.Accounts.WatchlistAddress do
  use Ecto.Schema
  import Ecto.Changeset

  alias Explorer.Accounts.Watchlist

  schema "account_watchlist_addresses" do
    field :hash, :string
    field :name, :string
    belongs_to(:watchlist, Watchlist)

    timestamps()
  end

  @doc false
  def changeset(watchlist_address, attrs) do
    watchlist_address
    |> cast(attrs, [:name, :hash])
    |> validate_required([:name, :hash])
  end
end
