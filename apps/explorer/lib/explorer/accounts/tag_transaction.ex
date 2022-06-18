defmodule Explorer.Accounts.TagTransaction do
  @moduledoc """
    This is a personal tag for transaction
  """

  use Explorer.Schema

  import Ecto.Changeset

  alias Explorer.Accounts.Identity
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

  @doc false
  def changeset(tag, attrs) do
    tag
    |> cast(attrs, [:name, :identity_id, :tx_hash])
    |> validate_required([:name, :identity_id, :tx_hash])
    |> foreign_key_constraint(:tx_hash)
  end

  def tag_transaction_by_id_and_identity_id_query(tag_id, identity_id)
      when not is_nil(tag_id) and not is_nil(identity_id) do
    __MODULE__
    |> where([tag], tag.identity_id == ^identity_id and tag.id == ^tag_id)
  end

  def tag_transaction_by_id_and_identity_id_query(_, _), do: nil

  def delete_tag_transaction(tag_id, identity_id) when not is_nil(tag_id) and not is_nil(identity_id) do
    tag_id
    |> tag_transaction_by_id_and_identity_id_query(identity_id)
    |> Repo.delete_all()
  end

  def delete_tag_transaction(_, _), do: nil
end
