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

  alias Explorer.Chain.Cache.BackgroundMigrations

  alias Explorer.Migrator.{DeleteNonConsensusLogs, HeavyDbIndexOperation}

  @table_name :logs
  @index_name "logs_block_number_transaction_index_index_index"
  @operation_type :create
  @table_columns (case @chain_identity do
                    {:optimism, :celo} -> ["block_number", "index"]
                    _ -> ["block_number", "transaction_index", "index"]
                  end)
  @unique_index true

  @impl HeavyDbIndexOperation
  def dependent_from_migrations,
    do: [
      DeleteNonConsensusLogs.migration_name()
    ]

  @impl HeavyDbIndexOperation
  def update_cache do
    BackgroundMigrations.set_create_logs_block_number_transaction_index_index_unique_index_finished(true)
  end
end
