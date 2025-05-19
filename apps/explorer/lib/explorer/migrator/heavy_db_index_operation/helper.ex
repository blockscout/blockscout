defmodule Explorer.Migrator.HeavyDbIndexOperation.Helper do
  @moduledoc """
  Common functions for Explorer.Migrator.HeavyDbIndexOperation.* modules
  """

  require Logger

  alias Ecto.Adapters.SQL
  alias Explorer.Repo

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
