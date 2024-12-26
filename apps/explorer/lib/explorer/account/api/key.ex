defmodule Explorer.Account.Api.Key do
  @moduledoc """
    Module is responsible for schema for API keys, keys is used to track number of requests to the API endpoints
  """
  use Explorer.Schema

  alias Ecto.Multi
  alias Explorer.Account.Identity
  alias Ecto.{Changeset, UUID}
  alias Explorer.Repo

  import Ecto.Changeset

  @max_key_per_account 3

  @primary_key false
  typed_schema "account_api_keys" do
    field(:name, :string, null: false)
    field(:value, UUID, primary_key: true, null: false)
    belongs_to(:identity, Identity, null: false)

    timestamps()
  end

  @attrs ~w(value name identity_id)a

  @user_not_found "User not found"

  def changeset do
    %__MODULE__{}
    |> cast(%{}, @attrs)
  end

  def changeset(%__MODULE__{} = api_key, attrs \\ %{}) do
    api_key
    |> cast(attrs, @attrs)
    |> validate_required(@attrs, message: "Required")
    |> validate_length(:name, min: 1, max: 255)
    |> unique_constraint(:value, message: "API key already exists")
    |> foreign_key_constraint(:identity_id, message: @user_not_found)
    |> api_key_count_constraint()
  end

  @doc """
  Creates a new API key associated with an identity or returns an error when no identity is specified.

  When `identity_id` is provided in the attributes, the function acquires a lock on the
  identity record and creates a new API key within a transaction. If the identity is not
  found or if the changeset validation fails, returns an error.

  When `identity_id` is not provided, immediately returns an error with an invalid
  changeset.

  ## Parameters
  - `attrs`: A map of attributes that may contain:
    - `identity_id`: The ID of the identity to associate the API key with
    - `name`: The name for the API key (required, 1 to 255 characters)
    - `value`: Optional. If not provided, will be auto-generated using UUID v4

  ## Returns
  - `{:ok, api_key}` if the API key was created successfully
  - `{:error, changeset}` if validation fails or when no identity is provided
  """
  @spec create(map()) :: {:ok, t()} | {:error, Changeset.t()}
  def create(%{identity_id: identity_id} = attrs) do
    Multi.new()
    |> Identity.acquire_with_lock(identity_id)
    |> Multi.insert(:api_key, fn _ ->
      %__MODULE__{}
      |> changeset(Map.put(attrs, :value, generate_api_key()))
    end)
    |> Repo.account_repo().transaction()
    |> case do
      {:ok, %{api_key: api_key}} ->
        {:ok, api_key}

      {:error, :acquire_identity, :not_found, _changes} ->
        {:error,
         %__MODULE__{}
         |> changeset(Map.put(attrs, :value, generate_api_key()))
         |> add_error(:identity_id, @user_not_found,
           constraint: :foreign,
           constraint_name: "account_api_keys_identity_id_fkey"
         )}

      {:error, _failed_operation, error, _changes} ->
        {:error, error}
    end
  end

  def create(attrs) do
    {:error, %__MODULE__{} |> changeset(Map.put(attrs, :value, generate_api_key()))}
  end

  def api_key_count_constraint(%Changeset{changes: %{identity_id: identity_id}} = api_key) do
    if identity_id
       |> api_keys_by_identity_id_query()
       |> limit(@max_key_per_account)
       |> Repo.account_repo().aggregate(:count, :value) >= @max_key_per_account do
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
    |> order_by([api_key], desc: api_key.inserted_at)
  end

  def api_keys_by_identity_id_query(_), do: nil

  def api_key_by_value_and_identity_id_query(api_key_value, identity_id)
      when not is_nil(api_key_value) and not is_nil(identity_id) do
    __MODULE__
    |> where([api_key], api_key.identity_id == ^identity_id and api_key.value == ^api_key_value)
  end

  def api_key_by_value_and_identity_id_query(_, _), do: nil

  def get_api_key_by_value_and_identity_id(value, identity_id) when not is_nil(value) and not is_nil(identity_id) do
    value
    |> api_key_by_value_and_identity_id_query(identity_id)
    |> Repo.account_repo().one()
  end

  def get_api_key_by_value_and_identity_id(_, _), do: nil

  def update(%{value: api_key_value, identity_id: identity_id} = attrs) do
    with api_key <- get_api_key_by_value_and_identity_id(api_key_value, identity_id),
         false <- is_nil(api_key) do
      api_key |> changeset(attrs) |> Repo.account_repo().update()
    else
      true ->
        {:error, %{reason: :item_not_found}}
    end
  end

  def delete(api_key_value, identity_id) when not is_nil(api_key_value) and not is_nil(identity_id) do
    api_key_value
    |> api_key_by_value_and_identity_id_query(identity_id)
    |> Repo.account_repo().delete_all()
  end

  def delete(_, _), do: nil

  def get_api_keys_by_identity_id(id) when not is_nil(id) do
    id
    |> api_keys_by_identity_id_query()
    |> Repo.account_repo().all()
  end

  def get_api_keys_by_identity_id(_), do: nil

  def api_key_with_plan_by_value(api_key_value) when not is_nil(api_key_value) do
    if match?({:ok, _casted_api_key}, UUID.cast(api_key_value)) do
      __MODULE__
      |> where([api_key], api_key.value == ^api_key_value)
      |> Repo.account_repo().one()
      |> Repo.account_repo().preload(identity: :plan)
    else
      nil
    end
  end

  def api_key_with_plan_by_value(_), do: nil

  def get_max_api_keys_count, do: @max_key_per_account

  @doc """
  Merges API keys from multiple identities into a primary identity.

  This function updates the `identity_id` of all API keys belonging to the
  identities specified in `ids_to_merge` to the `primary_id`. It's designed to
  be used as part of an Ecto.Multi transaction.

  ## Parameters
  - `multi`: An Ecto.Multi struct to which this operation will be added.
  - `primary_id`: The ID of the primary identity that will own the merged keys.
  - `ids_to_merge`: A list of identity IDs whose API keys will be merged.

  ## Returns
  - An updated Ecto.Multi struct with the merge operation added.
  """
  @spec merge(Multi.t(), integer(), [integer()]) :: Multi.t()
  def merge(multi, primary_id, ids_to_merge) do
    Multi.run(multi, :merge_keys, fn repo, _ ->
      {:ok,
       repo.update_all(
         from(key in __MODULE__, where: key.identity_id in ^ids_to_merge),
         set: [identity_id: primary_id]
       )}
    end)
  end
end
