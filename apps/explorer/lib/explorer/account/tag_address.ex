defmodule Explorer.Account.TagAddress do
  @moduledoc """
    Watchlist is root entity for WatchlistAddresses
  """

  use Explorer.Schema

  import Ecto.Changeset

  alias Ecto.Changeset
  alias Explorer.Account.Identity
  alias Explorer.{Chain, PagingOptions, Repo}
  alias Explorer.Chain.{Address, Hash}

  import Explorer.Chain, only: [hash_to_lower_case_string: 1]

  schema "account_tag_addresses" do
    field(:address_hash_hash, Cloak.Ecto.SHA256)
    field(:name, Explorer.Encrypted.Binary)
    field(:address_hash, Explorer.Encrypted.AddressHash)

    belongs_to(:identity, Identity)

    timestamps()
  end

  @attrs ~w(name identity_id address_hash)a

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
    |> unique_constraint([:identity_id, :address_hash_hash], message: "Address tag already exists")
    |> check_existence_or_create_address()
    |> tag_address_count_constraint()
  end

  def create(attrs) do
    %__MODULE__{}
    |> changeset(attrs)
    |> Repo.account_repo().insert()
  end

  defp put_hashed_fields(changeset) do
    changeset
    |> put_change(:address_hash_hash, hash_to_lower_case_string(get_field(changeset, :address_hash)))
  end

  defp check_existence_or_create_address(%Changeset{changes: %{address_hash: address_hash}, valid?: true} = changeset) do
    check_existence_or_create_address_inner(changeset, address_hash)
  end

  defp check_existence_or_create_address(changeset), do: changeset

  defp check_existence_or_create_address_inner(changeset, address_hash) do
    with {:ok, hash} <- Hash.Address.cast(address_hash),
         {:ok, %Address{}} <- Chain.find_or_insert_address_from_hash(hash, []) do
      changeset
    end
  end

  def tag_address_count_constraint(%Changeset{changes: %{identity_id: identity_id}} = tag_address) do
    max_tags_count = get_max_tags_count()

    if identity_id
       |> tags_address_by_identity_id_query()
       |> limit(^max_tags_count)
       |> Repo.account_repo().aggregate(:count, :id) >= max_tags_count do
      tag_address
      |> add_error(:name, "Max #{max_tags_count} tags per account")
    else
      tag_address
    end
  end

  def tag_address_count_constraint(changeset), do: changeset

  def tags_address_by_identity_id_query(id) when not is_nil(id) do
    __MODULE__
    |> where([tag], tag.identity_id == ^id)
  end

  def tags_address_by_identity_id_query(_), do: nil

  @doc """
    Query paginated private address tags by identity id
  """
  @spec get_tags_address_by_identity_id(integer(), [Chain.paging_options()]) :: [__MODULE__]
  def get_tags_address_by_identity_id(id, options \\ [])

  def get_tags_address_by_identity_id(id, options) when not is_nil(id) do
    paging_options = Keyword.get(options, :paging_options, Chain.default_paging_options())

    id
    |> tags_address_by_identity_id_query()
    |> order_by([tag], desc: tag.id)
    |> page_address_tags(paging_options)
    |> limit(^paging_options.page_size)
    |> Repo.account_repo().all()
  end

  def get_tags_address_by_identity_id(_, _), do: []

  defp page_address_tags(query, %PagingOptions{key: {id}}) do
    query
    |> where([tag], tag.id < ^id)
  end

  defp page_address_tags(query, _), do: query

  def tag_address_by_address_hash_and_identity_id_query(address_hash, identity_id)
      when not is_nil(address_hash) and not is_nil(identity_id) do
    __MODULE__
    |> where([tag], tag.identity_id == ^identity_id and tag.address_hash == ^address_hash)
  end

  def tag_address_by_address_hash_and_identity_id_query(_, _), do: nil

  def get_tag_address_by_address_hash_and_identity_id(address_hash, identity_id)
      when not is_nil(address_hash) and not is_nil(identity_id) do
    address_hash
    |> hash_to_lower_case_string()
    |> tag_address_by_address_hash_and_identity_id_query(identity_id)
    |> Repo.account_repo().one()
  end

  def get_tag_address_by_address_hash_and_identity_id(_, _), do: nil

  def tag_address_by_id_and_identity_id_query(tag_id, identity_id)
      when not is_nil(tag_id) and not is_nil(identity_id) do
    __MODULE__
    |> where([tag], tag.identity_id == ^identity_id and tag.id == ^tag_id)
  end

  def tag_address_by_id_and_identity_id_query(_, _), do: nil

  def get_tag_address_by_id_and_identity_id_query(tag_id, identity_id)
      when not is_nil(tag_id) and not is_nil(identity_id) do
    tag_id
    |> tag_address_by_id_and_identity_id_query(identity_id)
    |> Repo.account_repo().one()
  end

  def get_tag_address_by_id_and_identity_id_query(_, _), do: nil

  def delete(tag_id, identity_id) when not is_nil(tag_id) and not is_nil(identity_id) do
    tag_id
    |> tag_address_by_id_and_identity_id_query(identity_id)
    |> Repo.account_repo().delete_all()
  end

  def delete(_, _), do: nil

  def update(%{id: tag_id, identity_id: identity_id} = attrs) do
    with tag <- get_tag_address_by_id_and_identity_id_query(tag_id, identity_id),
         false <- is_nil(tag) do
      tag |> changeset(attrs) |> Repo.account_repo().update()
    else
      true ->
        {:error, %{reason: :item_not_found}}
    end
  end

  def get_max_tags_count, do: Application.get_env(:explorer, Explorer.Account)[:private_tags_limit]
end
