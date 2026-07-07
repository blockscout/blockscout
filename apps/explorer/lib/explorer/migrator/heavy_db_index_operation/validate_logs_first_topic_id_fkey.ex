# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Migrator.HeavyDbIndexOperation.ValidateLogsFirstTopicIdFkey do
  @moduledoc """
  Validates `logs_first_topic_id_fkey` constraint.
  """

  use Explorer.Migrator.HeavyDbIndexOperation

  require Logger

  alias Explorer.Migrator.{FillLogsOptimizedFields, HeavyDbIndexOperation, MigrationStatus}

  @table_name :logs
  @index_name "logs_first_topic_id_fkey_constraint"
  @operation_type :create
  @constraint_name "logs_first_topic_id_fkey"

  @impl HeavyDbIndexOperation
  def table_name, do: @table_name

  @impl HeavyDbIndexOperation
  def operation_type, do: @operation_type

  @impl HeavyDbIndexOperation
  def index_name, do: @index_name

  @impl HeavyDbIndexOperation
  def dependent_from_migrations,
    do: [
      FillLogsOptimizedFields.migration_name()
    ]

  @impl HeavyDbIndexOperation
  # sobelow_skip ["SQL"]
  def db_index_operation do
    Logger.info("Migration ValidateLogsFirstTopicIdFkey started")

    case Repo.query(validate_constraint_query_string(), [], timeout: :infinity) do
      {:ok, _} ->
        Logger.info("Migration ValidateLogsFirstTopicIdFkey finished")
        :ok

      {:error, error} ->
        Logger.error("Migration ValidateLogsFirstTopicIdFkey failed: #{inspect(error)}")

        :error
    end
  end

  @impl HeavyDbIndexOperation
  def check_db_index_operation_progress do
    HeavyDbIndexOperationHelper.check_db_index_operation_progress(@index_name, validate_constraint_query_string())
  end

  @impl HeavyDbIndexOperation
  # sobelow_skip ["SQL"]
  # credo:disable-for-next-line Credo.Check.Refactor.CyclomaticComplexity
  def db_index_operation_status do
    {started?, completed?} =
      case Repo.query("""
           SELECT convalidated
           FROM pg_constraint
           WHERE conname = '#{@constraint_name}';
           """) do
        {:ok, %Postgrex.Result{rows: [[true]]}} -> {true, true}
        {:ok, %Postgrex.Result{rows: [[false]]}} -> {true, false}
        {:ok, %Postgrex.Result{rows: [[]]}} -> {false, false}
        _ -> {nil, nil}
      end

    cond do
      completed? -> :completed
      started? -> :not_completed
      is_nil(completed?) or is_nil(started?) -> :unknown
      true -> :not_initialized
    end
  end

  @impl HeavyDbIndexOperation
  # sobelow_skip ["SQL"]
  def restart_db_index_operation do
    case Repo.query("""
         SELECT pg_cancel_backend(pid)
         FROM pg_stat_activity
         WHERE pid <> pg_backend_pid()
           AND query = '#{validate_constraint_query_string()}'
           AND state = 'active';
         """) do
      {:ok, _} -> :ok
      _ -> :error
    end
  end

  @impl HeavyDbIndexOperation
  def running_other_heavy_migration_exists?(migration_name) do
    MigrationStatus.running_other_heavy_migration_for_table_exists?(@table_name, migration_name)
  end

  @impl HeavyDbIndexOperation
  def update_cache, do: :ok

  defp validate_constraint_query_string do
    "ALTER TABLE #{@table_name} VALIDATE CONSTRAINT #{@constraint_name};"
  end
end
