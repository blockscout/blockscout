defmodule Explorer.Accounts.TagAddress do
  @moduledoc """
    Watchlist is root entity for WatchlistAddresses
  """

  use Explorer.Schema

  import Ecto.Changeset

  alias Explorer.Accounts.Identity
  alias Explorer.Chain.{Address, Hash}
  alias Explorer.Repo

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

  def tag_address_by_id_and_identity_id_query(tag_id, identity_id)
      when not is_nil(tag_id) and not is_nil(identity_id) do
    __MODULE__
    |> where([tag], tag.identity_id == ^identity_id and tag.id == ^tag_id)
  end

  def tag_address_by_id_and_identity_id_query(_, _), do: nil

  def delete_tag_address(tag_id, identity_id) when not is_nil(tag_id) and not is_nil(identity_id) do
    tag_id
    |> tag_address_by_id_and_identity_id_query(identity_id)
    |> Repo.delete_all()
  end

  def delete_tag_address(_, _), do: nil
end
