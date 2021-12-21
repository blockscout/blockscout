defmodule Explorer.Accounts.Identity do
  @moduledoc """
    Identity of user fetched via Oauth
  """

  use Ecto.Schema
  import Ecto.Changeset
  alias Explorer.Accounts.Watchlist

  schema "account_identities" do
    field(:uid, :string)
    field(:email, :string)
    field(:name, :string)
    has_many(:watchlists, Watchlist)

    timestamps()
  end

  @doc false
  def changeset(identity, attrs) do
    identity
    |> cast(attrs, [:uid, :email, :name])
    |> validate_required([:uid, :email, :name])
  end
end
