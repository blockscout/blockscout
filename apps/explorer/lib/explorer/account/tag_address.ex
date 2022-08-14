defmodule Explorer.Account.TagAddress do
  @moduledoc """
    Watchlist is root entity for WatchlistAddresses
  """

  use Explorer.Schema

  import Ecto.Changeset

  alias Ecto.Changeset
  alias Explorer.Account.Identity
  alias Explorer.{Chain, Repo}
  alias Explorer.Chain.{Address, Hash}

  @max_tag_address_per_account 15

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
    |> unique_constraint([:identity_id, :address_hash], message: "Address tag already exists")
    |> check_existance_or_create_address()
    |> foreign_key_constraint(:address_hash, message: "")
    |> tag_address_count_constraint()
  end

  def create(attrs) do
    %__MODULE__{}
    |> changeset(attrs)
    |> Repo.insert()
  end

  defp check_existance_or_create_address(%Changeset{changes: %{address_hash: address_hash}, valid?: true} = changeset) do
    with {:ok, hash} <- Hash.Address.cast(address_hash),
         {:ok, %Address{}} <- Chain.find_or_insert_address_from_hash(hash, []) do
      changeset
    end
  end

  defp check_existance_or_create_address(changeset), do: changeset

  def tag_address_count_constraint(%Changeset{changes: %{identity_id: identity_id}} = tag_address) do
    if identity_id
       |> tags_address_by_identity_id_query()
       |> limit(@max_tag_address_per_account)
       |> Repo.aggregate(:count, :id) >= @max_tag_address_per_account do
      tag_address
      |> add_error(:name, "Max #{@max_tag_address_per_account} tags per account")
    else
      tag_address
    end
  end

  def tag_address_count_constraint(changeset), do: changeset

  def tags_address_by_identity_id_query(id) when not is_nil(id) do
    __MODULE__
    |> where([tag], tag.identity_id == ^id)
    |> order_by([tag], desc: tag.id)
  end

  def tags_address_by_identity_id_query(_), do: nil

  def get_tags_address_by_identity_id(id) when not is_nil(id) do
    id
    |> tags_address_by_identity_id_query()
    |> Repo.all()
  end

  def get_tags_address_by_identity_id(_), do: nil

  def tag_address_by_address_hash_and_identity_id_query(address_hash, identity_id)
      when not is_nil(address_hash) and not is_nil(identity_id) do
    __MODULE__
    |> where([tag], tag.identity_id == ^identity_id and tag.address_hash == ^address_hash)
  end

  def tag_address_by_address_hash_and_identity_id_query(_, _), do: nil

  def get_tag_address_by_address_hash_and_identity_id(address_hash, identity_id)
      when not is_nil(address_hash) and not is_nil(identity_id) do
    address_hash
    |> tag_address_by_address_hash_and_identity_id_query(identity_id)
    |> Repo.one()
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
    |> Repo.one()
  end

  def get_tag_address_by_id_and_identity_id_query(_, _), do: nil

  def delete(tag_id, identity_id) when not is_nil(tag_id) and not is_nil(identity_id) do
    tag_id
    |> tag_address_by_id_and_identity_id_query(identity_id)
    |> Repo.delete_all()
  end

  def delete(_, _), do: nil

  def update(%{id: tag_id, identity_id: identity_id} = attrs) do
    with tag <- get_tag_address_by_id_and_identity_id_query(tag_id, identity_id),
         false <- is_nil(tag) do
      tag |> changeset(attrs) |> Repo.update()
    else
      true ->
        {:error, %{reason: :item_not_found}}
    end
  end

  def get_max_tags_count, do: @max_tag_address_per_account
end
