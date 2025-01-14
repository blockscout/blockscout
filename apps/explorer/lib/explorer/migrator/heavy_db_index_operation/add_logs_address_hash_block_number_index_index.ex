defmodule Explorer.Migrator.HeavyDbIndexOperation.AddLogsAddressHashBlockNumberIndexIndex do
  @moduledoc """
  Add B-tree index `logs_address_hash_block_number_index_index` on `logs` table for (`address_hash`, `block_number`, `index`) columns.
  """

  use Explorer.Migrator.HeavyDbIndexOperation

  require Logger

  alias Explorer.Chain.Cache.BackgroundMigrations
  alias Explorer.Migrator.HeavyDbIndexOperation
  alias Explorer.Migrator.HeavyDbIndexOperation.Helper, as: HeavyDbIndexOperationHelper

  @migration_name "heavy_indexes_add_logs_address_hash_block_number_index_index"
  @index_name "logs_address_hash_block_number_index_index"
  @table_name "logs"
  @table_columns ["address_hash", "block_number", "index"]
  @dependent_from_migrations [
    "heavy_indexes_drop_logs_block_number_asc_index_asc_index",
    "heavy_indexes_add_logs_block_hash_index"
  ]

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
  def complete_db_index_operation do
    HeavyDbIndexOperationHelper.safely_drop_db_index(@index_name)
  end

  @impl HeavyDbIndexOperation
  def update_cache do
    BackgroundMigrations.set_heavy_indexes_add_logs_address_hash_block_number_index_index_finished(true)
  end
end
