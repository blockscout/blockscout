defmodule Explorer.Migrator.MigrationStatus do
  @moduledoc """
  Module is responsible for keeping the current status of background migrations.
  """
  use Explorer.Schema

  alias Explorer.Repo

  @primary_key false
  typed_schema "migrations_status" do
    field(:migration_name, :string, primary_key: true)
    # ["started", "completed"]
    field(:status, :string)
    field(:meta, :map)

    timestamps()
  end

  @doc false
  def changeset(migration_status \\ %__MODULE__{}, params) do
    cast(migration_status, params, [:migration_name, :status, :meta])
  end

  @doc """
  Get the `MigrationStatus` struct by migration name.
  """
  @spec fetch(String.t()) :: __MODULE__.t() | nil
  def fetch(migration_name) do
    migration_name
    |> get_by_migration_name_query()
    |> Repo.one()
  end

  @doc """
  Get the status of migration by its name.
  """
  @spec get_status(String.t()) :: String.t() | nil
  def get_status(migration_name) do
    migration_name
    |> get_by_migration_name_query()
    |> select([ms], ms.status)
    |> Repo.one()
  end

  @doc """
  Set the status of migration by its name.
  """
  @spec set_status(String.t(), String.t()) :: {:ok, __MODULE__.t()} | {:error, Ecto.Changeset.t()}
  def set_status(migration_name, status) do
    %{migration_name: migration_name, status: status}
    |> changeset()
    |> Repo.insert(on_conflict: {:replace_all_except, [:inserted_at, :meta]}, conflict_target: :migration_name)
  end

  @doc """
  Update migration meta by its name.
  """
  @spec update_meta(String.t(), map()) :: :ok | {:ok, __MODULE__.t()} | {:error, Ecto.Changeset.t()}
  def update_meta(migration_name, new_meta) do
    migration_name
    |> get_by_migration_name_query()
    |> Repo.one()
    |> case do
      nil ->
        :ok

      migration_status ->
        updated_meta = Map.merge(migration_status.meta || %{}, new_meta)

        migration_status
        |> changeset(%{meta: updated_meta})
        |> Repo.update()
    end
  end

  defp get_by_migration_name_query(query \\ __MODULE__, migration_name) do
    from(ms in query, where: ms.migration_name == ^migration_name)
  end
end
