defmodule Explorer.Migrator.HeavyDbIndexOperation.CreateInternalTransactionsBlockNumberTransactionIndexIndexUniqueIndex do
  @moduledoc """
  Create unique B-tree index `internal_transactions_block_number_transaction_index_index_index` on `internal_transactions` table for (`block_number`, `transaction_index`, `index`) columns.
  """

  use Explorer.Migrator.HeavyDbIndexOperation

  require Logger

  alias Explorer.Migrator.{
    EmptyInternalTransactionsData,
    HeavyDbIndexOperation,
    MigrationStatus,
    ReindexDuplicatedInternalTransactions
  }

  alias Explorer.Migrator.HeavyDbIndexOperation.Helper, as: HeavyDbIndexOperationHelper

  @table_name :internal_transactions
  @index_name "internal_transactions_block_number_transaction_index_index_index"
  @operation_type :create
  @table_columns ["block_number", "transaction_index", "index"]

  @impl HeavyDbIndexOperation
  def table_name, do: @table_name

  @impl HeavyDbIndexOperation
  def operation_type, do: @operation_type

  @impl HeavyDbIndexOperation
  def index_name, do: @index_name

  @impl HeavyDbIndexOperation
  def dependent_from_migrations,
    do: [
      ReindexDuplicatedInternalTransactions.migration_name(),
      EmptyInternalTransactionsData.migration_name()
    ]

  @impl HeavyDbIndexOperation
  def db_index_operation do
    HeavyDbIndexOperationHelper.create_db_index(@index_name, @table_name, @table_columns, true)
  end

  @impl HeavyDbIndexOperation
  def check_db_index_operation_progress do
    operation = HeavyDbIndexOperationHelper.create_index_query_string(@index_name, @table_name, @table_columns, true)
    HeavyDbIndexOperationHelper.check_db_index_operation_progress(@index_name, operation)
  end

  @impl HeavyDbIndexOperation
  def db_index_operation_status do
    HeavyDbIndexOperationHelper.db_index_creation_status(@index_name)
  end

  @impl HeavyDbIndexOperation
  def restart_db_index_operation do
    HeavyDbIndexOperationHelper.safely_drop_db_index(@index_name)
  end

  @impl HeavyDbIndexOperation
  def running_other_heavy_migration_exists?(migration_name) do
    MigrationStatus.running_other_heavy_migration_for_table_exists?(@table_name, migration_name)
  end

  @impl HeavyDbIndexOperation
  def update_cache, do: :ok
end
