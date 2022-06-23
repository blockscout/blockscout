defmodule Explorer.Account.TagTransaction do
  @moduledoc """
    This is a personal tag for transaction
  """

  use Explorer.Schema

  import Ecto.Changeset

  alias Explorer.Account.Identity
  alias Explorer.Chain.{Hash, Transaction}
  alias Explorer.Repo

  schema "account_tag_transactions" do
    field(:name, :string)
    belongs_to(:identity, Identity)

    belongs_to(:transaction, Transaction,
      foreign_key: :tx_hash,
      references: :hash,
      type: Hash.Full
    )

    timestamps()
  end

  @attrs ~w(name identity_id tx_hash)a

  @doc false
  def changeset(tag, attrs) do
    tag
    |> cast(attrs, @attrs)
    |> validate_required(@attrs)
    |> validate_length(:name, min: 1, max: 35)
    |> unique_constraint([:identity_id, :tx_hash], message: "Transaction tag already exists")
    |> foreign_key_constraint(:tx_hash, message: "Transaction does not exist")
  end

  def create(attrs) do
    %__MODULE__{}
    |> changeset(attrs)
    |> Repo.insert()
  end

  def tags_transaction_by_identity_id_query(id) when not is_nil(id) do
    __MODULE__
    |> where([tag], tag.identity_id == ^id)
  end

  def tags_transaction_by_identity_id_query(_), do: nil

  def get_tags_transaction_by_identity_id(id) when not is_nil(id) do
    id
    |> tags_transaction_by_identity_id_query()
    |> Repo.all()
  end

  def get_tags_transaction_by_identity_id(_), do: nil

  def tag_transaction_by_address_hash_and_identity_id_query(address_hash, identity_id)
      when not is_nil(address_hash) and not is_nil(identity_id) do
    __MODULE__
    |> where([tag], tag.identity_id == ^identity_id and tag.address_hash == ^address_hash)
  end

  def tag_transaction_by_address_hash_and_identity_id_query(_, _), do: nil

  def get_tag_transaction_by_address_hash_and_identity_id(address_hash, identity_id)
      when not is_nil(address_hash) and not is_nil(identity_id) do
    address_hash
    |> tag_transaction_by_address_hash_and_identity_id_query(identity_id)
    |> Repo.one()
  end

  def get_tag_transaction_by_address_hash_and_identity_id(_, _), do: nil

  def tag_transaction_by_id_and_identity_id_query(tag_id, identity_id)
      when not is_nil(tag_id) and not is_nil(identity_id) do
    __MODULE__
    |> where([tag], tag.identity_id == ^identity_id and tag.id == ^tag_id)
  end

  def tag_transaction_by_id_and_identity_id_query(_, _), do: nil

  def delete(tag_id, identity_id) when not is_nil(tag_id) and not is_nil(identity_id) do
    tag_id
    |> tag_transaction_by_id_and_identity_id_query(identity_id)
    |> Repo.delete_all()
  end

  def delete(_, _), do: nil
end
