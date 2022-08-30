defmodule Explorer.Account.TagTransaction do
  @moduledoc """
    This is a personal tag for transaction
  """

  use Explorer.Schema

  import Ecto.Changeset

  alias Ecto.Changeset
  alias Explorer.Account.Identity
  alias Explorer.{Chain, Repo}
  alias Explorer.Chain.Hash
  import Explorer.Chain, only: [hash_to_lower_case_string: 1]

  @max_tag_transaction_per_account 15

  schema "account_tag_transactions" do
    field(:name, :string)
    field(:tx_hash, Hash.Full, null: false)

    field(:encrypted_name, Explorer.Encrypted.Binary)
    field(:encrypted_tx_hash, Explorer.Encrypted.TransactionHash, null: false)
    field(:tx_hash_hash, Cloak.Ecto.SHA256)

    # field(:name, Explorer.Encrypted.Binary)
    # field(:tx_hash, Explorer.Encrypted.TransactionHash, null: false)

    belongs_to(:identity, Identity)

    timestamps()
  end

  @attrs ~w(name identity_id tx_hash)a

  def changeset do
    %__MODULE__{}
    |> cast(%{}, @attrs)
  end

  @doc false
  def changeset(tag, attrs) do
    tag
    |> cast(attrs, @attrs)
    |> validate_required(@attrs, message: "Required")
    |> validate_length(:name, min: 1, max: 35)
    |> put_hashed_fields()
    |> unique_constraint([:identity_id, :tx_hash_hash], message: "Transaction tag already exists")
    |> tag_transaction_count_constraint()
    |> check_transaction_existance()
  end

  def create(attrs) do
    %__MODULE__{}
    |> changeset(attrs)
    |> Repo.account_repo().insert()
  end

  defp put_hashed_fields(changeset) do
    changeset
    |> put_change(:tx_hash_hash, hash_to_lower_case_string(get_field(changeset, :tx_hash)))
  end

  defp check_transaction_existance(%Changeset{changes: %{tx_hash: tx_hash}} = changeset) do
    check_transaction_existance_inner(changeset, tx_hash)
  end

  defp check_transaction_existance(changeset), do: changeset

  defp check_transaction_existance_inner(changeset, tx_hash) do
    if match?({:ok, _}, Chain.hash_to_transaction(tx_hash)) do
      changeset
    else
      add_error(changeset, :tx_hash, "Transaction does not exist")
    end
  end

  def tag_transaction_count_constraint(%Changeset{changes: %{identity_id: identity_id}} = tag_transaction) do
    if identity_id
       |> tags_transaction_by_identity_id_query()
       |> limit(@max_tag_transaction_per_account)
       |> Repo.account_repo().aggregate(:count, :id) >= @max_tag_transaction_per_account do
      tag_transaction
      |> add_error(:name, "Max #{@max_tag_transaction_per_account} tags per account")
    else
      tag_transaction
    end
  end

  def tag_transaction_count_constraint(changeset), do: changeset

  def tags_transaction_by_identity_id_query(id) when not is_nil(id) do
    __MODULE__
    |> where([tag], tag.identity_id == ^id)
    |> order_by([tag], desc: tag.id)
  end

  def tags_transaction_by_identity_id_query(_), do: nil

  def get_tags_transaction_by_identity_id(id) when not is_nil(id) do
    id
    |> tags_transaction_by_identity_id_query()
    |> Repo.account_repo().all()
  end

  def get_tags_transaction_by_identity_id(_), do: nil

  def tag_transaction_by_transaction_hash_and_identity_id_query(tx_hash, identity_id)
      when not is_nil(tx_hash) and not is_nil(identity_id) do
    __MODULE__
    |> where([tag], tag.identity_id == ^identity_id and tag.tx_hash == ^tx_hash)
  end

  def tag_transaction_by_transaction_hash_and_identity_id_query(_, _), do: nil

  def get_tag_transaction_by_transaction_hash_and_identity_id(tx_hash, identity_id)
      when not is_nil(tx_hash) and not is_nil(identity_id) do
    tx_hash
    |> hash_to_lower_case_string()
    |> tag_transaction_by_transaction_hash_and_identity_id_query(identity_id)
    |> Repo.account_repo().one()
  end

  def get_tag_transaction_by_transaction_hash_and_identity_id(_, _), do: nil

  def tag_transaction_by_id_and_identity_id_query(tag_id, identity_id)
      when not is_nil(tag_id) and not is_nil(identity_id) do
    __MODULE__
    |> where([tag], tag.identity_id == ^identity_id and tag.id == ^tag_id)
  end

  def tag_transaction_by_id_and_identity_id_query(_, _), do: nil

  def get_tag_transaction_by_id_and_identity_id_query(tag_id, identity_id)
      when not is_nil(tag_id) and not is_nil(identity_id) do
    tag_id
    |> tag_transaction_by_id_and_identity_id_query(identity_id)
    |> Repo.account_repo().one()
  end

  def get_tag_transaction_by_id_and_identity_id_query(_, _), do: nil

  def delete(tag_id, identity_id) when not is_nil(tag_id) and not is_nil(identity_id) do
    tag_id
    |> tag_transaction_by_id_and_identity_id_query(identity_id)
    |> Repo.account_repo().delete_all()
  end

  def delete(_, _), do: nil

  def update(%{id: tag_id, identity_id: identity_id} = attrs) do
    with tag <- get_tag_transaction_by_id_and_identity_id_query(tag_id, identity_id),
         false <- is_nil(tag) do
      tag |> changeset(attrs) |> Repo.account_repo().update()
    else
      true ->
        {:error, %{reason: :item_not_found}}
    end
  end

  def get_max_tags_count, do: @max_tag_transaction_per_account
end
