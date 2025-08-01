defmodule Explorer.Migrator.MigrationStatus do
  @moduledoc """
  Module is responsible for keeping the current status of background migrations.
  """
  use Explorer.Schema

  alias Explorer.Migrator.HeavyDbIndexOperation.Helper, as: HeavyDbIndexOperationHelper
  alias Explorer.Repo

  @migration_name_atom :migration_name

  @typedoc """
    The structure of status of a migration:
    * `migration_name` - The name of the migration.
    * `status` - The status of the migration.
    * `meta` - The meta data of the migration.
  """
  @primary_key false
  typed_schema "migrations_status" do
    field(@migration_name_atom, :string, primary_key: true)
    # ["started", "completed"]
    field(:status, :string)
    field(:meta, :map)

    timestamps()
  end

  @doc false
  def changeset(migration_status \\ %__MODULE__{}, params) do
    cast(migration_status, params, [@migration_name_atom, :status, :meta])
  end

  @doc """
  Get the `MigrationStatus` struct by migration name.
  """
  @spec fetch(String.t()) :: __MODULE__.t() | nil
  def fetch(migration_name) do
    migration_name
    |> get_migration_by_name_query()
    |> Repo.one()
  end

  @doc """
  Get the status of migration by its name.
  """
  @spec get_status(String.t()) :: String.t() | nil
  def get_status(migration_name) do
    migration_name
    |> get_migration_by_name_query()
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
    |> Repo.insert(on_conflict: {:replace_all_except, [:inserted_at, :meta]}, conflict_target: @migration_name_atom)
  end

  @doc """
  Update migration meta by its name.
  """
  @spec update_meta(String.t(), map()) :: :ok | {:ok, __MODULE__.t()} | {:error, Ecto.Changeset.t()}
  def update_meta(migration_name, new_meta) do
    migration_name
    |> get_by_name()
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

  @doc """
  Set migration meta by its name.
  """
  @spec set_meta(String.t(), map() | nil) :: :ok | {:ok, __MODULE__.t()} | {:error, Ecto.Changeset.t()}
  def set_meta(migration_name, new_meta) do
    migration_name
    |> get_by_name()
    |> case do
      nil ->
        :ok

      migration_status ->
        migration_status
        |> changeset(%{meta: new_meta})
        |> Repo.update()
    end
  end

  # Builds a query to filter migration status records by migration name.
  #
  # ## Parameters
  # - `query`: The base query to build upon, defaults to the module itself
  # - `migration_name`: The name of the migration to filter by
  #
  # ## Returns
  # - An `Ecto.Query` that filters records where migration_name matches the provided value
  @spec get_migration_by_name_query(Ecto.Queryable.t(), String.t()) :: Ecto.Query.t()
  defp get_migration_by_name_query(query \\ __MODULE__, migration_name) do
    from(ms in query, where: ms.migration_name == ^migration_name)
  end

  @spec fetch_migration_statuses_query(Ecto.Queryable.t(), [String.t()]) :: Ecto.Query.t()
  defp fetch_migration_statuses_query(query \\ __MODULE__, migration_names) do
    from(ms in query,
      where: ms.migration_name in ^migration_names,
      select: ms.status
    )
  end

  defp get_by_name(migration_name) do
    migration_name
    |> get_migration_by_name_query()
    |> Repo.one()
  end

  @doc """
  Checks if there are any running heavy migrations except the current.

  A heavy migration is identified by its name starting with "heavy_indexes_create_{table_name}" or "heavy_indexes_drop_{table_name}" prefixes.
  """
  @spec running_other_heavy_migration_for_table_exists?(Ecto.Queryable.t(), atom(), String.t()) :: boolean()
  def running_other_heavy_migration_for_table_exists?(query \\ __MODULE__, table_name, migration_name) do
    heavy_migrations_create_prefix =
      "#{HeavyDbIndexOperationHelper.heavy_db_operation_migration_name_prefix()}create_#{to_string(table_name)}%"

    heavy_migrations_drop_prefix =
      "#{HeavyDbIndexOperationHelper.heavy_db_operation_migration_name_prefix()}drop_#{to_string(table_name)}%"

    query =
      from(ms in query,
        where:
          ilike(ms.migration_name, ^heavy_migrations_create_prefix) or
            ilike(ms.migration_name, ^heavy_migrations_drop_prefix),
        where: ms.migration_name != ^migration_name,
        where: ms.status == ^"started"
      )

    Repo.exists?(query)
  end

  @doc """
  Fetches the status of the given migrations.

  ## Parameters

    - migration_names: A list of migration names to check the status for.

  ## Returns

    - A list of migration statuses fetched from the database.

  """
  @spec fetch_migration_statuses([String.t()]) :: list(String.t())
  def fetch_migration_statuses(migration_names) do
    migration_names
    |> fetch_migration_statuses_query()
    |> Repo.all()
  end
end
