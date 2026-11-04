# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Migrator.HeavyDbIndexOperation.DropLogsAddressHashTransactionHashIndex do
  @moduledoc """
  Drops index "logs_address_hash_transaction_hash_index" btree (address_hash, transaction_hash).
  """

  use Explorer.Migrator.HeavyDbIndexOperation

  alias Explorer.Chain.Cache.BackgroundMigrations
  alias Explorer.Migrator.HeavyDbIndexOperation

  alias Explorer.Migrator.HeavyDbIndexOperation.{
    CreateLogsAddressHashBlockNumberDescIndexDescIndex,
    CreateLogsBlockHashIndex,
    DropLogsAddressHashIndex,
    DropLogsBlockNumberAscIndexAscIndex
  }

  @table_name :logs
  @index_name "logs_address_hash_transaction_hash_index"
  @operation_type :drop

  @impl HeavyDbIndexOperation
  def dependent_from_migrations,
    do: [
      DropLogsBlockNumberAscIndexAscIndex.migration_name(),
      CreateLogsBlockHashIndex.migration_name(),
      CreateLogsAddressHashBlockNumberDescIndexDescIndex.migration_name(),
      DropLogsAddressHashIndex.migration_name()
    ]

  @impl HeavyDbIndexOperation
  def update_cache do
    BackgroundMigrations.set_heavy_indexes_drop_logs_address_hash_transaction_hash_index_finished(true)
  end
end
