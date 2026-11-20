# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Migrator.HeavyDbIndexOperation.Helper do
  @moduledoc """
  Common functions for Explorer.Migrator.HeavyDbIndexOperation.* modules
  """

  require Logger

  alias Ecto.Adapters.SQL
  alias Explorer.Migrator.MigrationStatus
  alias Explorer.Repo

  # `VACUUM` and `REINDEX` leave nothing in the DB schema to tell a finished operation from
  # the one which hasn't been started, so their completion is recorded in the migration meta.
  @db_operation_finished_meta_key "db_operation_finished"

  @doc """
  Checks the progress of DB index operation by its name.
  """
  @spec check_db_index_operation_progress(String.t(), String.t()) ::
          :finished_or_not_started | :unknown | :in_progress
  def check_db_index_operation_progress(raw_index_name, operation) do
    index_name = sanitize_index_name(raw_index_name)

    case SQL.query(
           Repo,
           """
           SELECT EXISTS (SELECT 1 FROM pg_stat_activity WHERE state='active' AND query = $1);
           """,
           [operation]
         ) do
      {:ok, %Postgrex.Result{command: :select, columns: ["exists"], rows: [[true]]}} ->
        :in_progress

      {:ok, %Postgrex.Result{command: :select, columns: ["exists"], rows: [[false]]}} ->
        :finished_or_not_started

      {:error, error} ->
        Logger.error("Failed to check DB index '#{index_name}' operation progress: #{inspect(error)}")
        :unknown
    end
  end

  @doc """
  Checks DB index with the given name exists in the DB and it is valid.
  """
  @spec db_index_exists_and_valid?(String.t()) ::
          %{
            :exists? => boolean(),
            :valid? => boolean() | nil
          }
          | :unknown
  def db_index_exists_and_valid?(raw_index_name) do
    index_name = sanitize_index_name(raw_index_name)

    case SQL.query(
           Repo,
           """
           SELECT pg_index.indisvalid
           FROM pg_class, pg_index
           WHERE pg_index.indexrelid = pg_class.oid
           AND pg_class.relname = $1;
           """,
           [index_name]
         ) do
      {:ok, %Postgrex.Result{rows: []}} ->
        %{exists?: false, valid?: nil}

      {:ok, %Postgrex.Result{command: :select, columns: ["indisvalid"], rows: [[true]]}} ->
        %{exists?: true, valid?: true}

      {:ok, %Postgrex.Result{command: :select, columns: ["indisvalid"], rows: [[false]]}} ->
        %{exists?: true, valid?: false}

      {:error, error} ->
        Logger.error("Failed to check DB index '#{index_name}' existence: #{inspect(error)}")
        :unknown
    end
  end

  @doc """
  Returns status of DB index creation with the given name.
  """
  @spec db_index_creation_status(String.t()) :: :not_initialized | :not_completed | :completed | :unknown
  def db_index_creation_status(raw_index_name) do
    index_name = sanitize_index_name(raw_index_name)

    case db_index_exists_and_valid?(index_name) do
      %{exists?: false, valid?: nil} -> :not_initialized
      %{exists?: true, valid?: false} -> :not_completed
      %{exists?: true, valid?: true} -> :completed
      :unknown -> :unknown
    end
  end

  @doc """
  Returns status of DB index dropping with the given name.
  """
  @spec db_index_dropping_status(String.t()) :: :not_initialized | :not_completed | :completed | :unknown
  def db_index_dropping_status(raw_index_name) do
    index_name = sanitize_index_name(raw_index_name)

    case db_index_exists_and_valid?(index_name) do
      %{exists?: true, valid?: true} -> :not_initialized
      %{exists?: true, valid?: false} -> :not_completed
      %{exists?: false, valid?: nil} -> :completed
      :unknown -> :unknown
    end
  end

  @doc """
  Creates DB index with the given name and table name atom, if it doesn't exist.
  """
  @spec create_db_index(String.t(), atom(), list()) :: :ok | :error
  def create_db_index(raw_index_name, table_name_atom, table_columns, unique? \\ false) do
    index_name = sanitize_index_name(raw_index_name)
    query = create_index_query_string(index_name, table_name_atom, table_columns, unique?)
    run_create_db_index_query(query)
  end

  @doc """
  Creates DB index running the given query.
  """
  @spec create_db_index(String.t()) :: :ok | :error
  def create_db_index(query) do
    run_create_db_index_query(query)
  end

  @spec run_create_db_index_query(String.t()) :: :ok | :error
  # sobelow_skip ["SQL"]
  defp run_create_db_index_query(query) do
    case SQL.query(Repo, query, [], timeout: :infinity) do
      {:ok, _} ->
        :ok

      {:error, error} ->
        Logger.error("Failed to run create DB index query: #{inspect(error)}")

        :error
    end
  end

  @doc """
  Generates a SQL query string to create an index on a specified table.

  ## Parameters

    - `index_name` (String): The name of the index to be created.
    - `table_name_atom` (atom): The name of the table on which the index will be created, as an atom.
    - `table_columns` (list of strings): A list of column names to be included in the index.

  ## Returns

    - (String): A SQL query string to create the index.

  ## Examples

      iex> create_index_query_string("my_index", :my_table, ["column1", "column2"])
      "CREATE INDEX CONCURRENTLY IF NOT EXISTS \"my_index\" on my_table (column1, column2);"

  """
  @spec create_index_query_string(String.t(), atom(), list(), boolean()) :: String.t()
  def create_index_query_string(index_name, table_name_atom, table_columns, unique? \\ false) do
    "CREATE #{(unique? && "UNIQUE") || ""} INDEX #{add_concurrently_flag?()} IF NOT EXISTS \"#{index_name}\" on #{to_string(table_name_atom)} (#{Enum.join(table_columns, ", ")});"
  end

  @doc """
  Drops DB index by given name, if it exists.
  """
  @spec safely_drop_db_index(String.t()) :: :ok | :error
  # sobelow_skip ["SQL"]
  def safely_drop_db_index(raw_index_name) do
    index_name = sanitize_index_name(raw_index_name)

    case SQL.query(Repo, drop_index_query_string(index_name), [], timeout: :infinity) do
      {:ok, _} ->
        :ok

      {:error, error} ->
        Logger.error("Failed to drop DB index '#{index_name}': #{inspect(error)}")
        :error
    end
  end

  @doc """
  Cancels currently active index creating query.
  """
  @spec cancel_index_creating_query(String.t()) :: :ok | :error
  # sobelow_skip ["SQL"]
  def cancel_index_creating_query(raw_index_name) do
    index_name = sanitize_index_name(raw_index_name)

    case SQL.query(Repo, cancel_index_query_string(index_name), [], timeout: :infinity) do
      {:ok, _} ->
        :ok

      {:error, error} ->
        Logger.error("Failed to cancel creating DB index '#{index_name}': #{inspect(error)}")
        :error
    end
  end

  @doc """
  Vacuums the given table and records the completion in the meta of the given migration.
  """
  @spec vacuum_table(atom(), String.t()) :: :ok | :error
  # sobelow_skip ["SQL"]
  def vacuum_table(table_name, migration_name) do
    case SQL.query(Repo, vacuum_query_string(table_name), [], timeout: :infinity) do
      {:ok, _} ->
        mark_db_operation_finished(migration_name)

      {:error, error} ->
        Logger.error("Failed to vacuum the '#{table_name}' table: #{inspect(error)}")
        :error
    end
  end

  @doc """
  Returns status of the vacuum performed on the given table by the given migration.

  `:not_completed` means that the vacuum is still running.
  """
  @spec vacuuming_status(atom(), String.t()) :: :not_initialized | :not_completed | :completed | :unknown
  def vacuuming_status(table_name, migration_name) do
    if db_operation_finished?(migration_name) do
      :completed
    else
      case check_vacuum_progress(table_name) do
        :finished_or_not_started -> :not_initialized
        :in_progress -> :not_completed
        :unknown -> :unknown
      end
    end
  end

  @doc """
  Checks the progress of the vacuum of the given table.
  """
  @spec check_vacuum_progress(atom()) :: :finished_or_not_started | :unknown | :in_progress
  def check_vacuum_progress(table_name) do
    check_db_index_operation_progress(to_string(table_name), vacuum_query_string(table_name))
  end

  @doc """
  Tells if the vacuum of the given table can be started again.

  A vacuum leaves nothing to clean up, so a running one is waited for (`:error` makes the restart
  be retried later) instead of being cancelled.
  """
  @spec restart_vacuum(atom()) :: :ok | :error
  def restart_vacuum(table_name) do
    case check_vacuum_progress(table_name) do
      :finished_or_not_started -> :ok
      _ -> :error
    end
  end

  @doc """
  Rebuilds DB index with the given name and records the completion in the meta of the given migration.

  If the index doesn't exist, there is nothing to rebuild, and the operation is considered finished.
  """
  @spec reindex_db_index(String.t(), String.t()) :: :ok | :error
  # sobelow_skip ["SQL"]
  def reindex_db_index(raw_index_name, migration_name) do
    index_name = sanitize_index_name(raw_index_name)

    case db_index_exists_and_valid?(index_name) do
      %{exists?: false} ->
        Logger.warning("DB index '#{index_name}' doesn't exist, skipping its rebuild")
        mark_db_operation_finished(migration_name)

      %{exists?: true} ->
        case SQL.query(Repo, reindex_index_query_string(index_name), [], timeout: :infinity) do
          {:ok, _} ->
            mark_db_operation_finished(migration_name)

          {:error, error} ->
            Logger.error("Failed to rebuild DB index '#{index_name}': #{inspect(error)}")
            :error
        end

      :unknown ->
        :error
    end
  end

  @doc """
  Returns status of the rebuild of the index with the given name performed by the given migration.

  `:not_completed` means that a previous rebuild of this index was interrupted and left invalid
  indexes behind, see `drop_interrupted_reindex_leftovers/1`.
  """
  @spec db_index_reindexing_status(String.t(), String.t()) :: :not_initialized | :not_completed | :completed | :unknown
  def db_index_reindexing_status(raw_index_name, migration_name) do
    if db_operation_finished?(migration_name) do
      :completed
    else
      case interrupted_reindex_leftovers(raw_index_name) do
        {:ok, []} -> :not_initialized
        {:ok, _leftovers} -> :not_completed
        :error -> :unknown
      end
    end
  end

  @doc """
  Drops the invalid indexes left by an interrupted `REINDEX INDEX CONCURRENTLY` of the index with
  the given name.

  A concurrent rebuild which didn't finish (e.g. the application was restarted in the middle of it)
  leaves an invalid index with the `_ccnew` or `_ccold` suffix behind. Such an index is as large as
  the original one and is updated on every write, so it must be dropped before the next attempt.

  Only the leftovers of the given index are dropped, see `interrupted_reindex_leftovers/1`. Nothing
  is dropped while a rebuild of the index is running (`:error` makes the cleanup be retried later):
  its transient index is invalid until the rebuild finishes.
  """
  @spec drop_interrupted_reindex_leftovers(String.t()) :: :ok | :error
  def drop_interrupted_reindex_leftovers(raw_index_name) do
    index_name = sanitize_index_name(raw_index_name)

    with :finished_or_not_started <-
           check_db_index_operation_progress(index_name, reindex_index_query_string(index_name)),
         {:ok, leftovers} <- interrupted_reindex_leftovers(index_name) do
      if leftovers |> Enum.map(&safely_drop_db_index/1) |> Enum.all?(&(&1 == :ok)), do: :ok, else: :error
    else
      _ -> :error
    end
  end

  # Returns the names of the invalid indexes left by an interrupted concurrent rebuild of the
  # given index. An index is considered a leftover of the given one only if:
  #
  # - it has the name PostgreSQL gives to the transient index of the rebuild: the name of the
  #   rebuilt index, truncated to fit into 63 bytes together with the `_ccnew`/`_ccold` suffix
  #   (which is followed by a number if the name is already taken),
  # - and it is built on the same table, with the same access method, columns, operator classes
  #   and ordering options.
  #
  # The invalid indexes of the other operations on the same table are thus left untouched.
  defp interrupted_reindex_leftovers(raw_index_name) do
    index_name = sanitize_index_name(raw_index_name)

    case SQL.query(
           Repo,
           """
           SELECT leftover_class.relname
           FROM pg_class AS original_class
           JOIN pg_index AS original ON original.indexrelid = original_class.oid
           JOIN pg_index AS leftover ON leftover.indrelid = original.indrelid
           JOIN pg_class AS leftover_class ON leftover_class.oid = leftover.indexrelid
           CROSS JOIN LATERAL substring(leftover_class.relname from '_cc(?:new|old)[0-9]*$') AS suffix
           WHERE original_class.relname = $1
             AND leftover.indexrelid <> original.indexrelid
             AND NOT leftover.indisvalid
             AND suffix IS NOT NULL
             AND left(leftover_class.relname, length(leftover_class.relname) - length(suffix)) =
               left(original_class.relname, 63 - length(suffix))
             AND leftover_class.relam = original_class.relam
             AND leftover.indkey = original.indkey
             AND leftover.indclass = original.indclass
             AND leftover.indoption = original.indoption;
           """,
           [index_name]
         ) do
      {:ok, %Postgrex.Result{rows: rows}} ->
        {:ok, List.flatten(rows)}

      {:error, error} ->
        Logger.error("Failed to look for the leftovers of the '#{index_name}' index rebuild: #{inspect(error)}")
        :error
    end
  end

  defp mark_db_operation_finished(migration_name) do
    case MigrationStatus.update_meta(migration_name, %{@db_operation_finished_meta_key => true}) do
      {:error, error} ->
        Logger.error("Failed to record the completion of the '#{migration_name}' migration: #{inspect(error)}")
        :error

      _ ->
        :ok
    end
  end

  defp db_operation_finished?(migration_name) do
    match?(%{meta: %{@db_operation_finished_meta_key => true}}, MigrationStatus.fetch(migration_name))
  end

  @doc """
  Validates `NOT NULL` constraints for the given table columns and sets the columns to `NOT NULL`.

  The operation runs inside a transaction. For each column it first validates the corresponding
  check constraint and then alters the column to `NOT NULL`.
  """
  @spec validate_not_null_db_index_operation(atom(), [String.t()]) :: :ok | :error
  # sobelow_skip ["SQL"]
  def validate_not_null_db_index_operation(table_name, columns) do
    result =
      Repo.transaction(
        fn ->
          columns
          |> Enum.reduce_while(:ok, fn column, _acc ->
            # credo:disable-for-next-line Credo.Check.Refactor.Nesting
            with {:ok, _} <-
                   Repo.query(validate_not_null_constraint_query_string(table_name, column), [], timeout: :infinity),
                 {:ok, _} <- Repo.query(set_not_null_query_string(table_name, column)) do
              {:cont, :ok}
            else
              {:error, error} -> {:halt, {:error, error}}
            end
          end)
          |> case do
            :ok ->
              :ok

            {:error, error} ->
              Repo.rollback(error)
          end
        end,
        timeout: :infinity
      )

    case result do
      {:ok, :ok} ->
        :ok

      {:error, error} ->
        Logger.error("Migration validate #{table_name} #{inspect(columns)} not null failed: #{inspect(error)}")

        :error
    end
  end

  @doc """
  Checks the progress of `NOT NULL` constraint validation operation for the given table columns.
  """
  @spec validate_not_null_check_db_index_operation_progress(atom(), String.t(), [String.t()]) ::
          :finished_or_not_started | :unknown | :in_progress
  def validate_not_null_check_db_index_operation_progress(table_name, index_name, columns) do
    all_operations =
      Enum.flat_map(columns, fn column ->
        [
          validate_not_null_constraint_query_string(table_name, column),
          set_not_null_query_string(table_name, column)
        ]
      end)

    Enum.reduce_while(all_operations, :finished_or_not_started, fn operation, acc ->
      case check_db_index_operation_progress(index_name, operation) do
        :finished_or_not_started -> {:cont, acc}
        progress -> {:halt, progress}
      end
    end)
  end

  @doc """
  Returns status of `NOT NULL` constraint validation operation for the given table columns.
  """
  @spec validate_not_null_db_index_operation_status(atom(), [String.t()]) ::
          :not_initialized | :not_completed | :completed | :unknown
  # sobelow_skip ["SQL"]
  # credo:disable-for-next-line /Complexity/
  def validate_not_null_db_index_operation_status(table_name, columns) do
    column_name_condition = Enum.map_join(columns, " OR ", &"column_name = '#{&1}'")

    columns_count = Enum.count(columns)

    completed? =
      case Repo.query("""
           SELECT is_nullable
           FROM information_schema.columns
           WHERE table_name = '#{table_name}' AND (#{column_name_condition});
           """) do
        {:ok, %Postgrex.Result{rows: rows}} when length(rows) == columns_count ->
          Enum.all?(rows, &match?(["NO"], &1))

        _ ->
          nil
      end

    started? =
      case Repo.query("""
           SELECT convalidated
           FROM pg_constraint
           WHERE conname = '#{table_name}_#{List.first(columns)}_not_null';
           """) do
        {:ok, %Postgrex.Result{rows: [[true]]}} -> true
        {:ok, %Postgrex.Result{rows: [[false]]}} -> false
        _ -> nil
      end

    cond do
      completed? == true -> :completed
      started? == true -> :not_completed
      is_nil(completed?) or is_nil(started?) -> :unknown
      true -> :not_initialized
    end
  end

  @doc """
  Cancels currently active `NOT NULL` constraint validation queries for the given table columns.
  """
  @spec validate_not_null_restart_db_index_operation(atom(), [String.t()]) :: :ok | :error
  # sobelow_skip ["SQL"]
  def validate_not_null_restart_db_index_operation(table_name, columns) do
    query_condition =
      Enum.map_join(columns, " OR ", &"query ILIKE '%#{validate_not_null_constraint_query_string(table_name, &1)}%'")

    case Repo.query("""
         SELECT pg_cancel_backend(pid)
         FROM pg_stat_activity
         WHERE pid <> pg_backend_pid()
           AND (#{query_condition})
           AND state = 'active';
         """) do
      {:ok, _} -> :ok
      _ -> :error
    end
  end

  @doc """
  Returns the prefix used for naming heavy database operation migrations.

  ## Examples

      iex> Explorer.Migrator.HeavyDbIndexOperation.Helper.heavy_db_operation_migration_name_prefix()
      "heavy_indexes_"

  """
  @spec heavy_db_operation_migration_name_prefix() :: String.t()
  def heavy_db_operation_migration_name_prefix do
    "heavy_indexes_"
  end

  @doc """
  Generates a SQL query string to drop an index if it exists.

  ## Parameters

    - `raw_index_name`: The raw name of the index to be dropped.

  ## Returns

    - A string containing the SQL query to drop the index.

  The query string includes the `CONCURRENTLY` flag if applicable and ensures the index is dropped only if it exists.

  ## Examples

      iex> drop_index_query_string("my_index")
      "DROP INDEX CONCURRENTLY IF EXISTS \"my_index\";"
  """
  @spec drop_index_query_string(String.t()) :: String.t()
  def drop_index_query_string(raw_index_name) do
    index_name = sanitize_index_name(raw_index_name)
    "DROP INDEX #{add_concurrently_flag?()} IF EXISTS \"#{index_name}\";"
  end

  @doc """
  Generates a SQL query string to vacuum the given table.

  ## Examples

      iex> Explorer.Migrator.HeavyDbIndexOperation.Helper.vacuum_query_string(:token_transfers)
      "VACUUM token_transfers;"
  """
  @spec vacuum_query_string(atom()) :: String.t()
  def vacuum_query_string(table_name) do
    "VACUUM #{table_name};"
  end

  @doc """
  Generates a SQL query string to rebuild the index with the given name.

  The query string includes the `CONCURRENTLY` flag if applicable.
  """
  @spec reindex_index_query_string(String.t()) :: String.t()
  def reindex_index_query_string(raw_index_name) do
    index_name = sanitize_index_name(raw_index_name)
    "REINDEX INDEX #{add_concurrently_flag?()} \"#{index_name}\";"
  end

  @doc """
  Generates a SQL query string to cancel a currently active `CREATE INDEX` query.
  """
  @spec cancel_index_query_string(String.t()) :: String.t()
  def cancel_index_query_string(raw_index_name) do
    index_name = sanitize_index_name(raw_index_name)

    """
    SELECT pg_cancel_backend(pid)
    FROM pg_stat_activity
    WHERE pid <> pg_backend_pid()
      AND query ILIKE '%create%index%'
      AND query ILIKE '%#{index_name}%'
      AND state = 'active';
    """
  end

  @doc """
  Generates a SQL query string to validate a `NOT NULL` check constraint for the given table column.
  """
  @spec validate_not_null_constraint_query_string(atom(), String.t()) :: String.t()
  def validate_not_null_constraint_query_string(table_name, column) do
    "ALTER TABLE #{table_name} VALIDATE CONSTRAINT #{table_name}_#{column}_not_null;"
  end

  @doc """
  Generates a SQL query string to set the given table column to `NOT NULL`.
  """
  @spec set_not_null_query_string(atom(), String.t()) :: String.t()
  def set_not_null_query_string(table_name, column) do
    "ALTER TABLE #{table_name} ALTER COLUMN #{column} SET NOT NULL;"
  end

  @doc """
  As a workaround we have to remove `CONCURRENTLY` in tests since
  the error like "DROP INDEX CONCURRENTLY cannot run inside a transaction
  block" is returned with it.
  """
  @spec add_concurrently_flag?() :: String.t()
  def add_concurrently_flag? do
    if Mix.env() == :test, do: "", else: "CONCURRENTLY"
  end

  defp sanitize_index_name(raw_index_name) do
    # Postgres allows index names with a maximum length of 63 bytes
    if byte_size(raw_index_name) < 64 do
      raw_index_name
    else
      <<index_name::binary-size(63), _::binary>> = raw_index_name
      index_name
    end
  end

  @doc """
    Returns the configured check interval for heavy DB operations.
    If not configured, defaults to 10 minutes.

    ## Examples

        iex> get_check_interval()
        600_000 # 10 minutes in milliseconds

  """
  @spec get_check_interval() :: timeout()
  def get_check_interval do
    Application.get_env(:explorer, Explorer.Migrator.HeavyDbIndexOperation)[:check_interval] ||
      :timer.minutes(10)
  end
end
