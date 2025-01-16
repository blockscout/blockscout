defmodule Explorer.Migrator.HeavyDbIndexOperation.AddInternalTransactionsBlockNumberDescTransactionIndexDescIndexDescIndex do
  @moduledoc """
  Add B-tree index `internal_transactions_block_number_DESC_transaction_index_DESC_index_DESC_index` on `internal_transactions` table for (`block_number` DESC, `transaction_index` DESC, `index` DESC) columns.
  """

  use Explorer.Migrator.HeavyDbIndexOperation

  require Logger

  alias Explorer.Chain.Cache.BackgroundMigrations
  alias Explorer.Migrator.HeavyDbIndexOperation
  alias Explorer.Migrator.HeavyDbIndexOperation.Helper, as: HeavyDbIndexOperationHelper

  @migration_name "heavy_indexes_add_internal_transactions_block_number_desc_transaction_index_desc_index_desc_index"
  @index_name "internal_transactions_block_number_DESC_transaction_index_DESC_index_DESC_index"
  @table_name "internal_transactions"
  @table_columns ["block_number DESC", "transaction_index DESC", "index DESC"]
  @dependent_from_migrations ["heavy_indexes_drop_internal_transactions_from_address_hash_index"]

  @impl HeavyDbIndexOperation
  def migration_name, do: @migration_name

  @impl HeavyDbIndexOperation
  def dependent_from_migrations do
    @dependent_from_migrations
  end

  @impl HeavyDbIndexOperation
  def db_index_operation do
    HeavyDbIndexOperationHelper.create_db_index(@index_name, @table_name, @table_columns)
  end

  @impl HeavyDbIndexOperation
  def check_db_index_operation_progress do
    HeavyDbIndexOperationHelper.check_db_index_creation_progress(@index_name)
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
  def update_cache do
    BackgroundMigrations.set_heavy_indexes_add_internal_transactions_block_number_desc_transaction_index_desc_index_desc_index_finished(
      true
    )
  end
end
