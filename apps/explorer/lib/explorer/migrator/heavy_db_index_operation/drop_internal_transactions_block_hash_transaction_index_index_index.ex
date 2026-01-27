defmodule Explorer.Migrator.HeavyDbIndexOperation.DropInternalTransactionsBlockHashTransactionIndexIndexIndex do
  @moduledoc """
  Drops index "internal_transactions_block_hash_transaction_index_index_index" btree (block_hash, transaction_index, index).
  """

  use Explorer.Migrator.HeavyDbIndexOperation

  alias Explorer.Migrator.{
    EmptyInternalTransactionsData,
    HeavyDbIndexOperation,
    MigrationStatus
  }

  alias Explorer.Migrator.HeavyDbIndexOperation.Helper, as: HeavyDbIndexOperationHelper

  @table_name :internal_transactions
  @index_name "internal_transactions_block_hash_transaction_index_index_index"
  @operation_type :drop

  @impl HeavyDbIndexOperation
  def table_name, do: @table_name

  @impl HeavyDbIndexOperation
  def operation_type, do: @operation_type

  @impl HeavyDbIndexOperation
  def index_name, do: @index_name

  @impl HeavyDbIndexOperation
  def dependent_from_migrations do
    [
      EmptyInternalTransactionsData.migration_name()
    ]
  end

  @impl HeavyDbIndexOperation
  def db_index_operation do
    with :ok <- HeavyDbIndexOperationHelper.cancel_index_creating_query(@index_name) do
      HeavyDbIndexOperationHelper.safely_drop_db_index(@index_name)
    end
  end

  @impl HeavyDbIndexOperation
  def check_db_index_operation_progress do
    operation = HeavyDbIndexOperationHelper.drop_index_query_string(@index_name)
    HeavyDbIndexOperationHelper.check_db_index_operation_progress(@index_name, operation)
  end

  @impl HeavyDbIndexOperation
  def db_index_operation_status do
    HeavyDbIndexOperationHelper.db_index_dropping_status(@index_name)
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
