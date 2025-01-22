defmodule Explorer.Migrator.HeavyDbIndexOperation.Helper do
  @moduledoc """
  Common functions for Explorer.Migrator.HeavyDbIndexOperation.* modules
  """

  require Logger

  alias Ecto.Adapters.SQL
  alias Explorer.Repo

  @doc """
  Checks the progress of DB index dropping by its name.
  """
  @spec check_db_index_operation_progress(String.t()) ::
          :finished_or_not_started | :unknown | :in_progress
  def check_db_index_operation_progress(raw_index_name) do
    index_name = sanitize_index_name(raw_index_name)

    case SQL.query(
           Repo,
           """
           SELECT EXISTS (SELECT 1 FROM pg_stat_activity WHERE state='active' AND query = $1);
           """,
           [drop_index_query_string(index_name)]
         ) do
      {:ok, %Postgrex.Result{command: :select, columns: ["exists"], rows: [[true]]}} ->
        :in_progress

      {:ok, %Postgrex.Result{command: :select, columns: ["exists"], rows: [[false]]}} ->
        :finished_or_not_started

      {:error, error} ->
        Logger.error("Failed to check DB index '#{index_name}' dropping progress: #{inspect(error)}")
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
  # sobelow_skip ["SQL"]
  def create_db_index(raw_index_name, table_name_atom, table_columns) do
    index_name = sanitize_index_name(raw_index_name)

    query =
      "CREATE INDEX #{add_concurrently_flag?()} IF NOT EXISTS \"#{index_name}\" on #{to_string(table_name_atom)} (#{Enum.join(table_columns, ", ")});"

    case SQL.query(Repo, query, [], timeout: :infinity) do
      {:ok, _} ->
        :ok

      {:error, error} ->
        Logger.error(
          "Failed to create DB index '#{index_name}' on table '#{to_string(table_name_atom)}' for columns #{inspect(table_columns)}: #{inspect(error)}"
        )

        :error
    end
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

  defp drop_index_query_string(raw_index_name) do
    index_name = sanitize_index_name(raw_index_name)
    "DROP INDEX #{add_concurrently_flag?()} IF EXISTS \"#{index_name}\";"
  end

  # As a workaround we have to remove `CONCURRENTLY` in tests since
  # the error like "DROP INDEX CONCURRENTLY cannot run inside a transaction block" is returned with it.
  defp add_concurrently_flag? do
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
end
