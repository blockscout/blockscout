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

    field(:encrypted_uid, Explorer.Encrypted.Binary)
    field(:encrypted_email, Explorer.Encrypted.Binary)
    field(:encrypted_name, Explorer.Encrypted.Binary)
    field(:encrypted_nickname, Explorer.Encrypted.Binary)
    field(:encrypted_avatar, Explorer.Encrypted.Binary)

    field(:uid_hash, Cloak.Ecto.SHA256)

    # field(:uid, Explorer.Encrypted.Binary)
    # field(:email, Explorer.Encrypted.Binary)
    # field(:name, Explorer.Encrypted.Binary)
    # field(:nickname, Explorer.Encrypted.Binary)
    # field(:avatar, Explorer.Encrypted.Binary)

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
