# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Migrator.HeavyDbIndexOperation.CreateDeletedInternalTransactionsAddressPlaceholdersBlockNumberIndex do
  @moduledoc """
  Create B-tree index `deleted_internal_transactions_address_placeholders_block_number` on
  `deleted_internal_transactions_address_placeholders` table for (`block_number`) column.

  The primary key starts with `address_id`, so the placeholders of a block can't be found without this index. They
  are deleted by block when the internal transactions of the block are processed again or the block is reorged (see
  `Explorer.Utility.InternalTransactionsAddressPlaceholder.delete_by_block_numbers/3`).
  """

  use Explorer.Migrator.HeavyDbIndexOperation

  alias Explorer.Chain.Cache.BackgroundMigrations
  alias Explorer.Migrator.{HeavyDbIndexOperation, MigrationStatus}
  alias Explorer.Migrator.HeavyDbIndexOperation.Helper, as: HeavyDbIndexOperationHelper

  @table_name :deleted_internal_transactions_address_placeholders
  # Postgres identifiers are limited to 63 bytes, the name with `_index` suffix would be truncated
  @index_name "deleted_internal_transactions_address_placeholders_block_number"
  @operation_type :create
  @table_columns ["block_number"]

  @impl HeavyDbIndexOperation
  def table_name, do: @table_name

  @impl HeavyDbIndexOperation
  def operation_type, do: @operation_type

  @impl HeavyDbIndexOperation
  def index_name, do: @index_name

  @impl HeavyDbIndexOperation
  def dependent_from_migrations, do: []

  @impl HeavyDbIndexOperation
  def db_index_operation do
    HeavyDbIndexOperationHelper.create_db_index(@index_name, @table_name, @table_columns)
  end

  @impl HeavyDbIndexOperation
  def check_db_index_operation_progress do
    operation = HeavyDbIndexOperationHelper.create_index_query_string(@index_name, @table_name, @table_columns)
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
  def update_cache do
    BackgroundMigrations.set_heavy_indexes_create_deleted_internal_transactions_address_placeholders_block_number_index_finished(
      true
    )
  end
end
