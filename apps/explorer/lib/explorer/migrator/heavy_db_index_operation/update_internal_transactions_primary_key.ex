defmodule Explorer.Migrator.HeavyDbIndexOperation.UpdateInternalTransactionsPrimaryKey do
  @moduledoc """
  Update primary key on `internal_transactions` table from (`block_hash`, `block_index`) to (`block_number`, `transaction_index`, `index`).
  """

  use Explorer.Migrator.HeavyDbIndexOperation

  require Logger

  alias Explorer.Chain.Cache.BackgroundMigrations
  alias Explorer.Migrator.{HeavyDbIndexOperation, MigrationStatus}

  alias Explorer.Migrator.HeavyDbIndexOperation.{
    CreateInternalTransactionsBlockNumberTransactionIndexIndexUniqueIndex,
    ValidateInternalTransactionsBlockNumberTransactionIndexNotNull
  }

  alias Explorer.Repo

  @table_name :internal_transactions
  @index_name "internal_transactions_pkey"
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
      ValidateInternalTransactionsBlockNumberTransactionIndexNotNull.migration_name()
    ]

  @impl HeavyDbIndexOperation
  # sobelow_skip ["SQL"]
  def db_index_operation do
    result =
      Repo.transaction(fn ->
        with {:ok, _} <- Repo.query(drop_pk_constraint_query_string()),
             {:ok, _} <- Repo.query(rename_index_query_string()),
             {:ok, _} <- Repo.query(add_new_pk_query_string()),
             {:ok, _} <- Repo.query(drop_block_index_not_null_query_string()),
             {:ok, _} <- Repo.query(drop_block_hash_not_null_query_string()) do
          update_cache()
          :ok
        else
          {:error, error} ->
            Repo.rollback(error)
        end
      end)

    case result do
      {:ok, :ok} ->
        :ok

      {:error, error} ->
        Logger.error("Migration UpdateInternalTransactionsPrimaryKey failed: #{inspect(error)}")
        :error
    end
  end

  @impl HeavyDbIndexOperation
  def check_db_index_operation_progress do
    all_operations = [
      drop_pk_constraint_query_string(),
      rename_index_query_string(),
      add_new_pk_query_string(),
      drop_block_index_not_null_query_string(),
      drop_block_hash_not_null_query_string()
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
           WHERE table_name = '#{@table_name}' AND column_name = 'block_index';
           """) do
        {:ok, %Postgrex.Result{rows: [["YES"]]}} -> true
        {:ok, %Postgrex.Result{rows: [["NO"]]}} -> false
        _ -> nil
      end

    started? =
      case Repo.query("""
           SELECT EXISTS (
             SELECT 1
             FROM information_schema.table_constraints
             WHERE table_schema = 'public'
               AND table_name   = '#{@table_name}'
               AND constraint_type = 'PRIMARY KEY'
           );
           """) do
        {:ok, %Postgrex.Result{rows: [[false]]}} -> true
        {:ok, %Postgrex.Result{rows: [[true]]}} -> false
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
    result =
      Repo.transaction(fn ->
        with {:ok, _} <- Repo.query(drop_pk_constraint_query_string()),
             {:ok, _} <- Repo.query(set_block_index_not_null_query_string()),
             {:ok, _} <- Repo.query(set_block_hash_not_null_query_string()),
             {:ok, _} <- Repo.query(add_old_pk_query_string()) do
          :ok
        else
          {:error, error} ->
            Repo.rollback(error)
        end
      end)

    case result do
      {:ok, :ok} ->
        :ok

      {:error, error} ->
        Logger.error("Migration UpdateInternalTransactionsPrimaryKey rollback failed: #{inspect(error)}")
        :error
    end
  end

  @impl HeavyDbIndexOperation
  def running_other_heavy_migration_exists?(migration_name) do
    MigrationStatus.running_other_heavy_migration_for_table_exists?(@table_name, migration_name)
  end

  @impl HeavyDbIndexOperation
  def update_cache do
    BackgroundMigrations.set_heavy_indexes_update_internal_transactions_primary_key_finished(true)
  end

  defp drop_pk_constraint_query_string do
    "ALTER TABLE #{@table_name} DROP CONSTRAINT #{@index_name};"
  end

  defp rename_index_query_string do
    "ALTER INDEX #{CreateInternalTransactionsBlockNumberTransactionIndexIndexUniqueIndex.index_name()} RENAME TO #{@index_name};"
  end

  defp add_new_pk_query_string do
    "ALTER TABLE #{@table_name} ADD PRIMARY KEY USING INDEX #{@index_name};"
  end

  defp add_old_pk_query_string do
    "ALTER TABLE #{@table_name} ADD PRIMARY KEY (block_hash, block_index);"
  end

  defp drop_block_index_not_null_query_string do
    "ALTER TABLE #{@table_name} ALTER COLUMN block_index DROP NOT NULL;"
  end

  defp set_block_index_not_null_query_string do
    "ALTER TABLE #{@table_name} ALTER COLUMN block_index SET NOT NULL;"
  end

  defp drop_block_hash_not_null_query_string do
    "ALTER TABLE #{@table_name} ALTER COLUMN block_hash DROP NOT NULL;"
  end

  defp set_block_hash_not_null_query_string do
    "ALTER TABLE #{@table_name} ALTER COLUMN block_hash SET NOT NULL;"
  end
end
