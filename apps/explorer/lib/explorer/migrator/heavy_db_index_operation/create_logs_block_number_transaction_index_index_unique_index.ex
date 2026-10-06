# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Migrator.HeavyDbIndexOperation.CreateLogsBlockNumberTransactionIndexIndexUniqueIndex do
  @moduledoc """
  Create unique B-tree index `logs_block_number_transaction_index_index_index` on `logs` table for (`block_number`, `transaction_index`, `index`) columns.

  The index becomes the primary key of `logs` in
  `Explorer.Migrator.HeavyDbIndexOperation.UpdateLogsPrimaryKey`. On Celo, logs may be emitted by
  the block itself, so `transaction_index` is nullable there and is excluded from the index. The
  index name is kept the same for all chain types since it is used to track the migration status.
  """

  use Explorer.Migrator.HeavyDbIndexOperation

  use Utils.CompileTimeEnvHelper, chain_identity: [:explorer, :chain_identity]

  require Logger

  alias Explorer.Chain.Cache.BackgroundMigrations

  alias Explorer.Migrator.{
    DeleteNonConsensusLogs,
    HeavyDbIndexOperation,
    MigrationStatus
  }

  alias Explorer.Migrator.HeavyDbIndexOperation.Helper, as: HeavyDbIndexOperationHelper

  @table_name :logs
  @index_name "logs_block_number_transaction_index_index_index"
  @operation_type :create
  @table_columns (case @chain_identity do
                    {:optimism, :celo} -> ["block_number", "index"]
                    _ -> ["block_number", "transaction_index", "index"]
                  end)

  @impl HeavyDbIndexOperation
  def table_name, do: @table_name

  @impl HeavyDbIndexOperation
  def operation_type, do: @operation_type

  @impl HeavyDbIndexOperation
  def index_name, do: @index_name

  @impl HeavyDbIndexOperation
  def dependent_from_migrations,
    do: [
      DeleteNonConsensusLogs.migration_name()
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
  def update_cache do
    BackgroundMigrations.set_create_logs_block_number_transaction_index_index_unique_index_finished(true)
  end
end
