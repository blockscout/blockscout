defmodule Explorer.Migrator.HeavyDbIndexOperation.DropLogsAddressHashTransactionHashIndex do
  @moduledoc """
  Drops index "logs_address_hash_transaction_hash_index" btree (address_hash, transaction_hash).
  """

  use Explorer.Migrator.HeavyDbIndexOperation

  alias Explorer.Chain.Cache.BackgroundMigrations
  alias Explorer.Migrator.{HeavyDbIndexOperation, MigrationStatus}

  alias Explorer.Migrator.HeavyDbIndexOperation.{
    CreateLogsAddressHashBlockNumberDescIndexDescIndex,
    CreateLogsBlockHashIndex,
    DropLogsAddressHashIndex,
    DropLogsBlockNumberAscIndexAscIndex
  }

  alias Explorer.Migrator.HeavyDbIndexOperation.Helper, as: HeavyDbIndexOperationHelper

  @table_name :logs
  @index_name "logs_address_hash_transaction_hash_index"
  @operation_type :drop

  @impl HeavyDbIndexOperation
  def table_name, do: @table_name

  @impl HeavyDbIndexOperation
  def operation_type, do: @operation_type

  @impl HeavyDbIndexOperation
  def index_name, do: @index_name

  @impl HeavyDbIndexOperation
  def dependent_from_migrations,
    do: [
      DropLogsBlockNumberAscIndexAscIndex.migration_name(),
      CreateLogsBlockHashIndex.migration_name(),
      CreateLogsAddressHashBlockNumberDescIndexDescIndex.migration_name(),
      DropLogsAddressHashIndex.migration_name()
    ]

  @impl HeavyDbIndexOperation
  def db_index_operation do
    HeavyDbIndexOperationHelper.safely_drop_db_index(@index_name)
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
  def update_cache do
    BackgroundMigrations.set_heavy_indexes_drop_logs_address_hash_transaction_hash_index_finished(true)
  end
end
