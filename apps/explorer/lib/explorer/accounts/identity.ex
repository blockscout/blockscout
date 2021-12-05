defmodule Explorer.Accounts.Identity do
  use Ecto.Schema
  import Ecto.Changeset
  alias Explorer.Accounts.Watchlist

  schema "account_identities" do
    field(:uid, :string)
    field(:email, :string)
    has_many(:watchlists, Watchlist)

    timestamps()
  end

  @doc false
  def changeset(identity, attrs) do
    identity
    |> cast(attrs, [:uid, :email])
    |> validate_required([:uid, :email])
  end
end
