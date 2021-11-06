defmodule Explorer.Accounts.Watchlist do
  use Ecto.Schema
  import Ecto.Changeset
  alias Explorer.Accounts.Identity

  schema "account_watchlists" do
    field(:name, :string)
    belongs_to(:identity, Identity)

    timestamps()
  end

  @doc false
  def changeset(watchlist, attrs) do
    watchlist
    |> cast(attrs, [:name])
    |> validate_required([:name])
  end
end
