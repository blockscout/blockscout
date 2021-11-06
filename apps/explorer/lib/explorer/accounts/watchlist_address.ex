defmodule Explorer.Accounts.WatchlistAddress do
  use Ecto.Schema
  import Ecto.Changeset

  schema "account_watchlist_addresses" do
    field :hash, :string
    field :name, :string
    field :watchlist_id, :id

    timestamps()
  end

  @doc false
  def changeset(watchlist_address, attrs) do
    watchlist_address
    |> cast(attrs, [:name, :hash])
    |> validate_required([:name, :hash])
  end
end
