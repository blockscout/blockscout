defmodule Explorer.Account.Api.Key do
  @moduledoc """
    Module is responsible for schema for API keys, keys is used to track number of requests to the API endpoints
  """
  use Explorer.Schema

  alias Explorer.Accounts.Identity
  alias Ecto.{Changeset, UUID}
  alias Explorer.Repo

  import Ecto.Changeset

  @max_key_per_account 3

  @primary_key false
  schema "account_api_keys" do
    field(:name, :string)
    field(:value, UUID, primary_key: true)
    belongs_to(:identity, Identity)

    timestamps()
  end

  @attrs ~w(value name identity_id)a

  def changeset do
    %__MODULE__{}
    |> cast(%{}, @attrs)
  end

  def changeset(%__MODULE__{} = api_key, attrs \\ %{}) do
    api_key
    |> cast(attrs, @attrs)
    |> validate_required(@attrs)
    |> validate_length(:name, min: 1, max: 255)
    |> unique_constraint(:value)
    |> foreign_key_constraint(:identity_id)
    |> api_key_count_constraint()
  end

  def create_api_key_changeset_and_insert(%__MODULE__{} = api_key \\ %__MODULE__{}, attrs \\ %{}) do
    api_key
    |> changeset(attrs)
    |> put_change(:value, generate_api_key())
    |> Repo.insert()
  end

  def api_key_count_constraint(%Changeset{changes: %{identity_id: identity_id}} = api_key) do
    if identity_id
       |> api_keys_by_identity_id_query()
       |> limit(@max_key_per_account)
       |> Repo.aggregate(:count, :value) >= @max_key_per_account do
      api_key
      |> add_error(:name, "Max #{@max_key_per_account} keys per account")
    else
      api_key
    end
  end

  def api_key_count_constraint(changeset), do: changeset

  def generate_api_key do
    UUID.generate()
  end

  def api_keys_by_identity_id_query(id) when not is_nil(id) do
    __MODULE__
    |> where([api_key], api_key.identity_id == ^id)
  end

  def api_keys_by_identity_id_query(_), do: nil

  def api_key_by_value_and_identity_id_query(api_key_value, identity_id)
      when not is_nil(api_key_value) and not is_nil(identity_id) do
    __MODULE__
    |> where([api_key], api_key.identity_id == ^identity_id and api_key.value == ^api_key_value)
  end

  def api_key_by_value_and_identity_id_query(_, _), do: nil

  def api_key_by_value_and_identity_id(value, identity_id) when not is_nil(value) and not is_nil(identity_id) do
    value
    |> api_key_by_value_and_identity_id_query(identity_id)
    |> Repo.one()
  end

  def api_key_by_value_and_identity_id(_, _), do: nil

  def update_api_key(%{value: api_key_value, identity_id: identity_id, name: name} = attrs) do
    with api_key <- api_key_by_value_and_identity_id(api_key_value, identity_id),
         false <- is_nil(api_key) do
      api_key |> changeset(attrs) |> Repo.update()
    else
      true ->
        {:error, %{reason: :item_not_found}}
    end
  end

  def delete_api_key(identity_id, api_key_value) when not is_nil(api_key_value) and not is_nil(identity_id) do
    api_key_value
    |> api_key_by_value_and_identity_id_query(identity_id)
    |> Repo.delete_all()
  end

  def delete_api_key(_, _), do: nil

  def to_string(api_key_value) do
    api_key_value
    |> Base.encode64()
  end

  def get_api_keys_by_identity_id(id) when not is_nil(id) do
    id
    |> api_keys_by_identity_id_query()
    |> Repo.all()
  end

  def get_api_keys_by_identity_id(_), do: nil

  def api_key_with_plan_by_value(api_key_value) when not is_nil(api_key_value) do
    if match?({:ok, _casted_api_key}, UUID.cast(api_key_value)) do
      __MODULE__
      |> where([api_key], api_key.value == ^api_key_value)
      |> Repo.one()
      |> Repo.preload(identity: :plan)
    else
      nil
    end
  end

  def api_key_with_plan_by_value(_), do: nil
end
