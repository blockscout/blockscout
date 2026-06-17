# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Migrator.HeavyDbIndexOperation.ValidateLogsBlockNumberTransactionIndexNotNull do
  @moduledoc """
  Validate `NOT NULL` constraints for `logs` (`block_number`, `transaction_index`).
  """

  use Explorer.Migrator.HeavyDbIndexOperation

  alias Explorer.Migrator.{HeavyDbIndexOperation, MigrationStatus}
  alias Explorer.Migrator.HeavyDbIndexOperation.CreateLogsBlockNumberTransactionIndexIndexUniqueIndex

  @table_name :logs
  @index_name "logs_not_null_constraints"
  @columns ["block_number", "transaction_index"]
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
      CreateLogsBlockNumberTransactionIndexIndexUniqueIndex.migration_name()
    ]

  @impl HeavyDbIndexOperation
  def db_index_operation do
    HeavyDbIndexOperationHelper.validate_not_null_db_index_operation(@table_name, @columns)
  end

  @impl HeavyDbIndexOperation
  def check_db_index_operation_progress do
    HeavyDbIndexOperationHelper.validate_not_null_check_db_index_operation_progress(@table_name, @index_name, @columns)
  end

  @impl HeavyDbIndexOperation
  def db_index_operation_status do
    HeavyDbIndexOperationHelper.validate_not_null_db_index_operation_status(@table_name, @columns)
  end

  @impl HeavyDbIndexOperation
  def restart_db_index_operation do
    HeavyDbIndexOperationHelper.validate_not_null_restart_db_index_operation(@table_name, @columns)
  end

  @impl HeavyDbIndexOperation
  def running_other_heavy_migration_exists?(migration_name) do
    MigrationStatus.running_other_heavy_migration_for_table_exists?(@table_name, migration_name)
  end

  @impl HeavyDbIndexOperation
  def update_cache, do: :ok
end
