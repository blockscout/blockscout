# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Migrator.HeavyDbIndexOperation.CreateLogsBlockHashIndex do
  @moduledoc """
  Create B-tree index on `logs` table for `block_hash` column.
  """

  use Explorer.Migrator.HeavyDbIndexOperation

  alias Explorer.Chain.Cache.BackgroundMigrations
  alias Explorer.Migrator.HeavyDbIndexOperation

  alias Explorer.Migrator.HeavyDbIndexOperation.DropLogsBlockNumberAscIndexAscIndex

  @table_name :logs
  @index_name "logs_block_hash_index"
  @operation_type :create
  @table_columns ["block_hash"]

  @impl HeavyDbIndexOperation
  def dependent_from_migrations,
    do: [
      DropLogsBlockNumberAscIndexAscIndex.migration_name()
    ]

  @impl HeavyDbIndexOperation
  def update_cache do
    BackgroundMigrations.set_heavy_indexes_create_logs_block_hash_index_finished(true)
  end
end
