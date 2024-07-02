defmodule Explorer.Account.Identity do
  @moduledoc """
    Identity of user fetched via Oauth
  """

  use Explorer.Schema

  import Ecto.Changeset

  alias Explorer.Account.Api.Plan
  alias Explorer.Account.{TagAddress, Watchlist}

  typed_schema "account_identities" do
    field(:uid_hash, Cloak.Ecto.SHA256) :: binary() | nil
    field(:uid, Explorer.Encrypted.Binary, null: false)
    field(:email, Explorer.Encrypted.Binary, null: false)
    field(:name, Explorer.Encrypted.Binary, null: false)
    field(:nickname, Explorer.Encrypted.Binary)
    field(:avatar, Explorer.Encrypted.Binary)
    field(:verification_email_sent_at, :utc_datetime_usec)

    has_many(:tag_addresses, TagAddress)
    has_many(:watchlists, Watchlist)

    belongs_to(:plan, Plan)

    timestamps()
  end

  @doc false
  def changeset(identity, attrs) do
    identity
    |> cast(attrs, [:uid, :email, :name, :nickname, :avatar, :verification_email_sent_at])
    |> validate_required([:uid, :email, :name])
    |> put_hashed_fields()
  end

  defp put_hashed_fields(changeset) do
    # Using force_change instead of put_change due to https://github.com/danielberkompas/cloak_ecto/issues/53
    changeset
    |> force_change(:uid_hash, get_field(changeset, :uid))
  end
end
