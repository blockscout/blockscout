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
    field(:api_key, UUID, primary_key: true)
    belongs_to(:identity, Identity)

    timestamps()
  end

  @attrs ~w(api_key name identity_id)a

  def changeset do
    %__MODULE__{}
    |> cast(%{}, @attrs)
  end

  def changeset(%__MODULE__{} = api_key, attrs \\ %{}) do
    api_key
    |> cast(attrs, @attrs)
    |> validate_required(@attrs)
  end

  def create_api_key_changeset_and_insert(%__MODULE__{} = api_key \\ %__MODULE__{}, attrs \\ %{}) do
    api_key
    |> cast(attrs, @attrs)
    |> put_change(:api_key, generate_api_key())
    |> validate_required(@attrs)
    |> unique_constraint(:api_key)
    |> api_key_count_constraint()
    |> Repo.insert()
  end

  def api_key_count_constraint(%Changeset{changes: %{identity_id: identity_id}} = api_key) do
    if identity_id
       |> api_keys_by_identity_id_query()
       |> limit(@max_key_per_account)
       |> Repo.aggregate(:count, :api_key) == @max_key_per_account do
      api_key
      |> add_error(:name, "Max #{@max_key_per_account} keys per account")
    else
      api_key
    end
  end

  def generate_api_key do
    UUID.generate()
  end

  def api_keys_by_identity_id_query(id) do
    __MODULE__
    |> where([api_key], api_key.identity_id == ^id)
  end

  def api_key_by_api_key_and_identity_id_query(api_key, identity_id) do
    __MODULE__
    |> where([api_key], api_key.identity_id == ^identity_id and api_key.api_key == ^api_key)
  end

  def api_key_by_api_key_and_identity_id(api_key, identity_id) do
    api_key
    |> api_key_by_api_key_and_identity_id_query(identity_id)
    |> Repo.one()
  end

  def update_name_api_key(new_name, identity_id, api_key) do
    api_key
    |> api_key_by_api_key_and_identity_id_query(identity_id)
    |> update([key], set: [name: ^new_name, updated_at: fragment("NOW()")])
    |> Repo.update_all([])
  end

  def delete_api_key(identity_id, api_key) do
    api_key
    |> api_key_by_api_key_and_identity_id_query(identity_id)
    |> Repo.delete_all()
  end

  def to_string(api_key_value) do
    api_key_value
    |> Base.encode64()
  end

  def get_api_keys_by_user_id(id) do
    id
    |> api_keys_by_identity_id_query()
    |> Repo.all()
  end

  def api_key_with_plan_by_api_key(api_key) do
    __MODULE__
    |> where([api_key], api_key.api_key == ^api_key)
    |> Repo.one()
    |> Repo.preload(identity: :plan)
  end

  def cast_api_key(api_key) do
    UUID.cast(api_key)
  end
end
