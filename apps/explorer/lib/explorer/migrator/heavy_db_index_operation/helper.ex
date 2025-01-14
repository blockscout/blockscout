defmodule Explorer.Migrator.HeavyDbIndexOperation.Helper do
  @moduledoc """
  Common functions for Explorer.Migrator.HeavyDbIndexOperation.* modules
  """

  require Logger

  alias Ecto.Adapters.SQL
  alias Explorer.Repo

  @doc """
  Checks the progress of DB index creation by its name.
  """
  @spec check_db_index_creation_progress(String.t()) ::
          :finished_or_not_started | :unknown | {:in_progress, String.t() | nil}
  def check_db_index_creation_progress(index_name) do
    case SQL.query(
           Repo,
           """
           SELECT
             now()::TIME(0),
             a.query,
             p.phase,
             round(p.blocks_done / p.blocks_total::numeric * 100, 2) AS "% done",
             p.blocks_total,
             p.blocks_done,
             p.tuples_total,
             p.tuples_done,
             ai.schemaname,
             ai.relname,
             ai.indexrelname
           FROM pg_stat_progress_create_index p
           JOIN pg_stat_activity a ON p.pid = a.pid
           LEFT JOIN pg_stat_all_indexes ai on ai.relid = p.relid AND ai.indexrelid = p.index_relid
           WHERE ai.relname = $1;
           """,
           [index_name]
         ) do
      {:ok, %Postgrex.Result{rows: []}} ->
        :finished_or_not_started

      {:ok, %Postgrex.Result{command: :select, columns: ["% done"], rows: [[percentage]]}} ->
        Logger.info("Heavy DB index '#{index_name}' creation progress #{percentage}%")

        if percentage < 100 do
          {:in_progress, "#{percentage} %"}
        else
          :finished_or_not_started
        end

      {:error, error} ->
        Logger.error("Failed to check DB index '#{index_name}' creation progress: #{inspect(error)}")
        :unknown
    end
  end

  @doc """
  Checks the progress of DB index dropping by its name.
  """
  @spec check_db_index_dropping_progress(String.t()) ::
          :finished_or_not_started | :unknown | {:in_progress, String.t() | nil}
  def check_db_index_dropping_progress(index_name) do
    case SQL.query(
           Repo,
           """
           SELECT EXISTS (SELECT 1 FROM pg_stat_activity WHERE state='active' AND query = $1);
           """,
           [drop_index_query_string(index_name)]
         ) do
      {:ok, %Postgrex.Result{command: :select, columns: ["exists"], rows: [[true]]}} ->
        {:in_progress, nil}

      {:ok, %Postgrex.Result{command: :select, columns: ["exists"], rows: [[false]]}} ->
        :finished_or_not_started

      {:error, error} ->
        Logger.error("Failed to check DB index '#{index_name}' creation progress: #{inspect(error)}")
        :unknown
    end
  end

  # Checks DB index with the given name exists in the DB and it is valid.
  @spec db_index_exists_and_valid?(String.t()) ::
          %{
            :exists? => boolean(),
            :valid? => boolean() | nil
          }
          | :unknown
  defp db_index_exists_and_valid?(index_name) do
    case SQL.query(
           Repo,
           """
           SELECT pg_index.indisvalid
           FROM pg_class, pg_index
           WHERE pg_index.indexrelid = pg_class.oid
           AND relname = $1;
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
  def db_index_creation_status(index_name) do
    case db_index_exists_and_valid?(index_name) do
      %{exists?: false, valid?: nil} -> :not_initialized
      %{exists?: true, valid?: false} -> :not_completed
      %{exists?: true, valid?: true} -> :completed
    end
  end

  @doc """
  Returns status of DB index dropping with the given name.
  """
  def db_index_dropping_status(index_name) do
    case db_index_exists_and_valid?(index_name) do
      %{exists?: true, valid?: true} -> :not_initialized
      %{exists?: true, valid?: false} -> :not_completed
      %{exists?: false, valid?: nil} -> :completed
    end
  end

  @doc """
  Creates DB index with the given name, if it doesn't exist.
  """
  @spec create_db_index(String.t(), String.t(), list()) :: :ok | :error
  # sobelow_skip ["SQL"]
  def create_db_index(index_name, table_name, table_columns) do
    query =
      "CREATE INDEX CONCURRENTLY IF NOT EXISTS \"#{index_name}\" on #{table_name} (#{Enum.join(table_columns, ", ")});"

    case SQL.query(Repo, query, []) do
      {:ok, _} ->
        :ok

      {:error, error} ->
        Logger.error(
          "Failed to create DB index '#{index_name}' on table '#{table_name}' for columns #{inspect(table_columns)}: #{inspect(error)}"
        )

        :error
    end
  end

  @doc """
  Drops DB index by given name, if it exists.
  """
  @spec safely_drop_db_index(String.t()) :: :ok | :error
  # sobelow_skip ["SQL"]
  def safely_drop_db_index(index_name) do
    case SQL.query(Repo, drop_index_query_string(index_name), []) do
      {:ok, _} ->
        :ok

      {:error, error} ->
        Logger.error("Failed to drop DB index '#{index_name}': #{inspect(error)}")
        :error
    end
  end

  defp drop_index_query_string(index_name) do
    "DROP INDEX IF EXISTS \"#{index_name}\";"
  end
end
