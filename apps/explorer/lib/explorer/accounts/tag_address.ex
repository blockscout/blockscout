defmodule Explorer.Accounts.TagAddress do
  @moduledoc """
    Watchlist is root entity for WatchlistAddresses
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias Explorer.Accounts.Identity
  alias Explorer.Chain.{Address, Hash}

  schema "account_tag_addresses" do
    field(:name, :string)
    belongs_to(:identity, Identity)

    belongs_to(:address, Address,
      foreign_key: :address_hash,
      references: :hash,
      type: Hash.Address
    )

    timestamps()
  end

  @doc false
  def changeset(tag, attrs) do
    tag
    |> cast(attrs, [:name, :identity_id, :address_hash])
    |> validate_required([:name, :identity_id, :address_hash])
  end
end
