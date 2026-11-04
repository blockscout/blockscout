# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Migrator.HeavyDbIndexOperation.CreateLogsAddressIdBlockNumberDescIndexDescIndex do
  @moduledoc """
  Create B-tree index `logs_address_id_block_number_DESC_index_DESC_index` on `logs` table for (`address_id`, `block_number DESC`, `index DESC`) columns.
  """

  use Explorer.Migrator.HeavyDbIndexOperation

  alias Explorer.Chain.Cache.BackgroundMigrations
  alias Explorer.Migrator.HeavyDbIndexOperation

  alias Explorer.Migrator.HeavyDbIndexOperation.CreateLogsBlockNumberTransactionIndexIndexUniqueIndex

  @table_name :logs
  @index_name "logs_address_id_block_number_DESC_index_DESC_index"
  @operation_type :create
  @table_columns ["address_id", "block_number DESC", "index DESC"]

  @impl HeavyDbIndexOperation
  def dependent_from_migrations, do: [CreateLogsBlockNumberTransactionIndexIndexUniqueIndex.migration_name()]

  @impl HeavyDbIndexOperation
  def update_cache do
    BackgroundMigrations.set_heavy_indexes_create_logs_address_id_block_number_desc_index_desc_index_finished(true)
  end
end
