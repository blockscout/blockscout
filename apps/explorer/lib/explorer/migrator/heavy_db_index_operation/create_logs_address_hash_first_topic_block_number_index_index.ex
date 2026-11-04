# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Migrator.HeavyDbIndexOperation.CreateLogsAddressHashFirstTopicBlockNumberIndexIndex do
  @moduledoc """
  Create B-tree index `logs_address_hash_first_topic_block_number_index_index` on `logs` table for (`address_hash`, `first_topic`, `block_number`, `index`) columns.
  """

  use Explorer.Migrator.HeavyDbIndexOperation

  alias Explorer.Chain.Cache.BackgroundMigrations
  alias Explorer.Migrator.HeavyDbIndexOperation

  alias Explorer.Migrator.HeavyDbIndexOperation.{
    CreateLogsAddressHashBlockNumberDescIndexDescIndex,
    CreateLogsBlockHashIndex,
    DropLogsAddressHashIndex,
    DropLogsAddressHashTransactionHashIndex,
    DropLogsBlockNumberAscIndexAscIndex,
    DropLogsIndexIndex
  }

  @table_name :logs
  @index_name "logs_address_hash_first_topic_block_number_index_index"
  @operation_type :create
  @table_columns ["address_hash", "first_topic", "block_number", "index"]

  @impl HeavyDbIndexOperation
  def dependent_from_migrations,
    do: [
      DropLogsBlockNumberAscIndexAscIndex.migration_name(),
      CreateLogsBlockHashIndex.migration_name(),
      CreateLogsAddressHashBlockNumberDescIndexDescIndex.migration_name(),
      DropLogsAddressHashIndex.migration_name(),
      DropLogsAddressHashTransactionHashIndex.migration_name(),
      DropLogsIndexIndex.migration_name()
    ]

  @impl HeavyDbIndexOperation
  def update_cache do
    BackgroundMigrations.set_heavy_indexes_create_logs_address_hash_first_topic_block_number_index_index_finished(true)
  end
end
