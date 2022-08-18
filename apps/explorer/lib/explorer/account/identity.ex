defmodule Explorer.Account.Identity do
  @moduledoc """
    Identity of user fetched via Oauth
  """

  use Explorer.Schema

  import Ecto.Changeset

  alias Explorer.Account.Api.Plan
  alias Explorer.Account.{TagAddress, Watchlist}

  schema "account_identities" do
    field(:uid, :string)
    field(:email, :string)
    field(:name, :string)
    field(:nickname, :string)
    field(:avatar, :string)
    has_many(:tag_addresses, TagAddress)
    has_many(:watchlists, Watchlist)
    belongs_to(:plan, Plan)

    timestamps()
  end

  @doc false
  def changeset(identity, attrs) do
    identity
    |> cast(attrs, [:uid, :email, :name, :nickname, :avatar])
    |> validate_required([:uid, :email, :name])
  end
end
