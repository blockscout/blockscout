defmodule Explorer.Account.TagTransaction do
  @moduledoc """
    This is a personal tag for transaction
  """

  use Explorer.Schema

  import Ecto.Changeset

  alias Ecto.{Changeset, Multi}
  alias Explorer.Account.Identity
  alias Explorer.{Chain, PagingOptions, Repo}
  alias Explorer.Chain.Hash
  import Explorer.Chain, only: [hash_to_lower_case_string: 1]

  @user_not_found "User not found"

  typed_schema "account_tag_transactions" do
    field(:transaction_hash_hash, Cloak.Ecto.SHA256) :: binary() | nil
    field(:name, Explorer.Encrypted.Binary, null: false)
    field(:transaction_hash, Explorer.Encrypted.TransactionHash, null: false)
    field(:user_created, :boolean, null: false, default: true)

    belongs_to(:identity, Identity, null: false)

    timestamps()
  end

  @attrs ~w(name identity_id transaction_hash)a

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
    |> foreign_key_constraint(:identity_id, message: @user_not_found)
    |> put_hashed_fields()
    |> unique_constraint([:identity_id, :transaction_hash_hash], message: "Transaction tag already exists")
    |> tag_transaction_count_constraint()
    |> check_transaction_existence()
  end

  @doc """
  Creates a new tag transaction record in a transactional context.

  Ensures data consistency by acquiring a lock on the associated identity record
  before creating the tag transaction. The operation either succeeds completely or
  fails without side effects.

  ## Parameters
  - `attrs`: A map of attributes that must include:
    - `:identity_id`: The ID of the associated identity

  ## Returns
  - `{:ok, tag_transaction}` - Successfully created tag transaction record
  - `{:error, changeset}` - A changeset with errors if:
    - The identity doesn't exist
    - The identity ID is missing from the attributes
    - The changeset validation fails
  """
  @spec create(map()) :: {:ok, t()} | {:error, Changeset.t()}
  def create(%{identity_id: identity_id} = attrs) do
    Multi.new()
    |> Identity.acquire_with_lock(identity_id)
    |> Multi.insert(:tag_transaction, fn _ ->
      %__MODULE__{}
      |> changeset(attrs)
    end)
    |> Repo.account_repo().transaction()
    |> case do
      {:ok, %{tag_transaction: tag_transaction}} ->
        {:ok, tag_transaction}

      {:error, :tag_transaction, :not_found, _changes} ->
        {:error,
         %__MODULE__{}
         |> changeset(attrs)
         |> add_error(:identity_id, @user_not_found,
           constraint: :foreign,
           constraint_name: "account_tag_transactions_identity_id_fkey"
         )}

      {:error, _failed_operation, error, _changes} ->
        {:error, error}
    end
  end

  def create(attrs) do
    {:error,
     %__MODULE__{}
     |> changeset(attrs)}
  end

  defp put_hashed_fields(changeset) do
    # Using force_change instead of put_change due to https://github.com/danielberkompas/cloak_ecto/issues/53
    changeset
    |> force_change(:transaction_hash_hash, hash_to_lower_case_string(get_field(changeset, :transaction_hash)))
  end

  defp check_transaction_existence(%Changeset{changes: %{transaction_hash: transaction_hash}} = changeset) do
    check_transaction_existence_inner(changeset, transaction_hash)
  end

  defp check_transaction_existence(changeset), do: changeset

  defp check_transaction_existence_inner(changeset, transaction_hash) do
    if match?({:ok, _}, Chain.hash_to_transaction(transaction_hash)) do
      changeset
    else
      add_error(changeset, :transaction_hash, "Transaction does not exist")
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

    case paging_options do
      %PagingOptions{key: {0}} ->
        []

      _ ->
        id
        |> tags_transaction_by_identity_id_query()
        |> order_by([tag], desc: tag.id)
        |> page_transaction_tags(paging_options)
        |> limit(^paging_options.page_size)
        |> Repo.account_repo().all()
    end
  end

  def get_tags_transaction_by_identity_id(_, _), do: []

  defp page_transaction_tags(query, %PagingOptions{key: {id}}) do
    query
    |> where([tag], tag.id < ^id)
  end

  defp page_transaction_tags(query, _), do: query

  @doc """
  Retrieves tag transactions for a given transaction hash and identity ID.

  This function queries the database for all tag transactions that match both
  the provided transaction hash and identity ID.

  ## Parameters
  - `transaction_hash`: The transaction hash to search for. Can be a `String.t()`,
    `Explorer.Chain.Hash.Full.t()`, or `nil`.
  - `identity_id`: The identity ID to search for. Can be an `integer()` or `nil`.

  ## Returns
  - A list of `Explorer.Account.TagTransaction` structs if matching records are found.
  - `nil` if either `transaction_hash` or `identity_id` is `nil`.
  """
  @spec get_tag_transaction_by_transaction_hash_and_identity_id(String.t() | Hash.Full.t() | nil, integer() | nil) ::
          [__MODULE__.t()] | nil
  def get_tag_transaction_by_transaction_hash_and_identity_id(transaction_hash, identity_id)
      when not is_nil(transaction_hash) and not is_nil(identity_id) do
    query =
      from(tag in __MODULE__, where: tag.transaction_hash_hash == ^transaction_hash and tag.identity_id == ^identity_id)

    Repo.account_repo().all(query)
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

  @doc """
  Merges transaction tags from multiple identities into a primary identity.

  This function updates the `identity_id` of all transaction tags belonging to the
  identities specified in `ids_to_merge` to the `primary_id`. It's designed to
  be used as part of an Ecto.Multi transaction.

  ## Parameters
  - `multi`: An Ecto.Multi struct to which this operation will be added.
  - `primary_id`: The ID of the primary identity that will own the merged keys.
  - `ids_to_merge`: A list of identity IDs whose transaction tags will be merged.

  ## Returns
  - An updated Ecto.Multi struct with the merge operation added.
  """
  @spec merge(Multi.t(), integer(), [integer()]) :: Multi.t()
  def merge(multi, primary_id, ids_to_merge) do
    Multi.run(multi, :merge_tag_transactions, fn repo, _ ->
      {:ok,
       repo.update_all(
         from(key in __MODULE__, where: key.identity_id in ^ids_to_merge),
         set: [identity_id: primary_id, user_created: false]
       )}
    end)
  end
end

defimpl Jason.Encoder, for: Explorer.Account.TagTransaction do
  def encode(transaction_tag, opts) do
    Jason.Encode.string(transaction_tag.name, opts)
  end
end
