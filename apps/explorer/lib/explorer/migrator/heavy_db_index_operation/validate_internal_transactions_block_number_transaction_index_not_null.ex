defmodule Explorer.Migrator.HeavyDbIndexOperation.ValidateInternalTransactionsBlockNumberTransactionIndexNotNull do
  @moduledoc """
  Validate `NOT NULL` constraints for `internal_transactions` (`block_number`, `transaction_index`).
  """

  use Explorer.Migrator.HeavyDbIndexOperation

  require Logger

  alias Explorer.Migrator.{HeavyDbIndexOperation, MigrationStatus}
  alias Explorer.Migrator.HeavyDbIndexOperation.CreateInternalTransactionsBlockNumberTransactionIndexIndexUniqueIndex
  alias Explorer.Repo

  @table_name :internal_transactions
  @index_name "internal_transactions_not_null_constraints"
  @operation_type :create

  @impl HeavyDbIndexOperation
  def table_name, do: @table_name

  @impl HeavyDbIndexOperation
  def operation_type, do: @operation_type

  @impl HeavyDbIndexOperation
  def index_name, do: @index_name

  @impl HeavyDbIndexOperation
  def dependent_from_migrations,
    do: [
      CreateInternalTransactionsBlockNumberTransactionIndexIndexUniqueIndex.migration_name()
    ]

  @impl HeavyDbIndexOperation
  # sobelow_skip ["SQL"]
  def db_index_operation do
    result =
      Repo.transaction(
        fn ->
          with {:ok, _} <- Repo.query(validate_constraint_query_string("block_number"), [], timeout: :infinity),
               {:ok, _} <- Repo.query(validate_constraint_query_string("transaction_index"), [], timeout: :infinity),
               {:ok, _} <- Repo.query(set_not_null_query_string("block_number")),
               {:ok, _} <- Repo.query(set_not_null_query_string("transaction_index")) do
            :ok
          else
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
        Logger.error(
          "Migration ValidateInternalTransactionsBlockNumberTransactionIndexNotNull failed: #{inspect(error)}"
        )

        :error
    end
  end

  @impl HeavyDbIndexOperation
  def check_db_index_operation_progress do
    all_operations = [
      validate_constraint_query_string("block_number"),
      validate_constraint_query_string("transaction_index"),
      set_not_null_query_string("block_number"),
      set_not_null_query_string("transaction_index")
    ]

    Enum.reduce_while(all_operations, :finished_or_not_started, fn operation, acc ->
      case HeavyDbIndexOperationHelper.check_db_index_operation_progress(@index_name, operation) do
        :finished_or_not_started -> {:cont, acc}
        progress -> {:halt, progress}
      end
    end)
  end

  @impl HeavyDbIndexOperation
  # credo:disable-for-next-line /Complexity/
  def db_index_operation_status do
    completed? =
      case Repo.query("""
           SELECT is_nullable
           FROM information_schema.columns
           WHERE table_name = '#{@table_name}' AND (column_name = 'block_number' OR column_name = 'transaction_index');
           """) do
        {:ok, %Postgrex.Result{rows: [["NO"], ["NO"]]}} -> true
        {:ok, %Postgrex.Result{rows: [_, _]}} -> false
        _ -> nil
      end

    started? =
      case Repo.query("""
           SELECT convalidated
           FROM pg_constraint
           WHERE conname = '#{@table_name}_block_number_not_null';
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

  @impl HeavyDbIndexOperation
  # sobelow_skip ["SQL"]
  def restart_db_index_operation do
    case Repo.query("""
         SELECT pg_cancel_backend(pid)
         FROM pg_stat_activity
         WHERE pid <> pg_backend_pid()
           AND (query ILIKE '%#{validate_constraint_query_string("block_number")}%' OR query ILIKE '%#{validate_constraint_query_string("transaction_index")}%')
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

  defp validate_constraint_query_string(column) do
    "ALTER TABLE #{@table_name} VALIDATE CONSTRAINT #{@table_name}_#{column}_not_null;"
  end

  defp set_not_null_query_string(column) do
    "ALTER TABLE #{@table_name} ALTER COLUMN #{column} SET NOT NULL;"
  end
end
