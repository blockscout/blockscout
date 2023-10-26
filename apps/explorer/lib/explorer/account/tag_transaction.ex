defmodule Explorer.Account.TagTransaction do
  @moduledoc """
    This is a personal tag for transaction
  """

  use Explorer.Schema

  import Ecto.Changeset

  alias Ecto.Changeset
  alias Explorer.Account.Identity
  alias Explorer.{Chain, PagingOptions, Repo}
  import Explorer.Chain, only: [hash_to_lower_case_string: 1]

  schema "account_tag_transactions" do
    field(:tx_hash_hash, Cloak.Ecto.SHA256)
    field(:name, Explorer.Encrypted.Binary)
    field(:tx_hash, Explorer.Encrypted.TransactionHash)

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
    |> check_transaction_existence()
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

  defp check_transaction_existence(%Changeset{changes: %{tx_hash: tx_hash}} = changeset) do
    check_transaction_existence_inner(changeset, tx_hash)
  end

  defp check_transaction_existence(changeset), do: changeset

  defp check_transaction_existence_inner(changeset, tx_hash) do
    if match?({:ok, _}, Chain.hash_to_transaction(tx_hash)) do
      changeset
    else
      add_error(changeset, :tx_hash, "Transaction does not exist")
    end
  end

  def tag_transaction_count_constraint(%Changeset{changes: %{identity_id: identity_id}} = tag_transaction) do
    max_tags_count = get_max_tags_count()

    if identity_id
       |> tags_transaction_by_identity_id_query()
       |> limit(^max_tags_count)
       |> Repo.account_repo().aggregate(:count, :id) >= max_tags_count do
      tag_transaction
      |> add_error(:name, "Max #{max_tags_count} tags per account")
    else
      tag_transaction
    end
  end

  def tag_transaction_count_constraint(changeset), do: changeset

  def tags_transaction_by_identity_id_query(id) when not is_nil(id) do
    __MODULE__
    |> where([tag], tag.identity_id == ^id)
  end

  def tags_transaction_by_identity_id_query(_), do: nil

  @doc """
    Query paginated private transaction tags by identity id
  """
  @spec get_tags_transaction_by_identity_id(integer(), [Chain.paging_options()]) :: [__MODULE__]
  def get_tags_transaction_by_identity_id(id, options \\ [])

  def get_tags_transaction_by_identity_id(id, options) when not is_nil(id) do
    paging_options = Keyword.get(options, :paging_options, Chain.default_paging_options())

    id
    |> tags_transaction_by_identity_id_query()
    |> order_by([tag], desc: tag.id)
    |> page_transaction_tags(paging_options)
    |> limit(^paging_options.page_size)
    |> Repo.account_repo().all()
  end

  def get_tags_transaction_by_identity_id(_, _), do: []

  defp page_transaction_tags(query, %PagingOptions{key: {id}}) do
    query
    |> where([tag], tag.id < ^id)
  end

  defp page_transaction_tags(query, _), do: query

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

  def get_max_tags_count, do: Application.get_env(:explorer, Explorer.Account)[:private_tags_limit]
end

defimpl Jason.Encoder, for: Explorer.Account.TagTransaction do
  def encode(tx_tag, opts) do
    Jason.Encode.string(tx_tag.name, opts)
  end
end
