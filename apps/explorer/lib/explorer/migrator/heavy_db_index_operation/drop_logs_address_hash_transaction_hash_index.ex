defmodule Explorer.Migrator.HeavyDbIndexOperation.DropLogsAddressHashTransactionHashIndex do
  @moduledoc """
  Drops index "logs_address_hash_transaction_hash_index" btree (address_hash, transaction_hash).
  """

  use Explorer.Migrator.HeavyDbIndexOperation

  alias Explorer.Chain.Cache.BackgroundMigrations
  alias Explorer.Migrator.{HeavyDbIndexOperation, MigrationStatus}
  alias Explorer.Migrator.HeavyDbIndexOperation.Helper, as: HeavyDbIndexOperationHelper

  @migration_name "heavy_indexes_drop_logs_address_hash_transaction_hash_index"
  @table_name :logs
  @index_name "logs_address_hash_transaction_hash_index"
  @operation_type :drop
  @dependent_from_migrations [
    "heavy_indexes_drop_logs_block_number_asc_index_asc_index",
    "heavy_indexes_create_logs_block_hash_index",
    "heavy_indexes_create_logs_address_hash_block_number_desc_index_desc_index",
    "heavy_indexes_drop_logs_address_hash_index"
  ]

  @impl HeavyDbIndexOperation
  def migration_name, do: @migration_name

  @impl HeavyDbIndexOperation
  def table_name, do: @table_name

  @impl HeavyDbIndexOperation
  def operation_type, do: @operation_type

  @impl HeavyDbIndexOperation
  def dependent_from_migrations, do: @dependent_from_migrations

  @impl HeavyDbIndexOperation
  def db_index_operation do
    HeavyDbIndexOperationHelper.safely_drop_db_index(@index_name)
  end

  @impl HeavyDbIndexOperation
  def check_db_index_operation_progress do
    HeavyDbIndexOperationHelper.check_db_index_dropping_progress(@index_name)
  end

  @impl HeavyDbIndexOperation
  def db_index_operation_status do
    HeavyDbIndexOperationHelper.db_index_dropping_status(@index_name)
  end

  @impl HeavyDbIndexOperation
  def restart_db_index_operation do
    HeavyDbIndexOperationHelper.safely_drop_db_index(@index_name, false)
  end

  @impl HeavyDbIndexOperation
  def running_other_heavy_migration_exists? do
    MigrationStatus.running_other_heavy_migration_for_table_exists?(@table_name, @migration_name)
  end

  @impl HeavyDbIndexOperation
  def update_cache do
    BackgroundMigrations.set_heavy_indexes_drop_logs_address_hash_transaction_hash_index_finished(true)
  end
end
