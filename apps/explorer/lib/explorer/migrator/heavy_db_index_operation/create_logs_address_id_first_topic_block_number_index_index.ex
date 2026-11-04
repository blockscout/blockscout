# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Migrator.HeavyDbIndexOperation.CreateLogsAddressIdFirstTopicBlockNumberIndexIndex do
  @moduledoc """
  Create B-tree index `logs_address_id_first_topic_id_block_number_index_index` on `logs` table for (`address_id`, `first_topic_id`, `block_number`, `index`) columns.
  """

  use Explorer.Migrator.HeavyDbIndexOperation

  alias Explorer.Chain.Cache.BackgroundMigrations
  alias Explorer.Migrator.HeavyDbIndexOperation
  alias Explorer.Migrator.HeavyDbIndexOperation.CreateLogsAddressIdBlockNumberDescIndexDescIndex

  @table_name :logs
  @index_name "logs_address_id_first_topic_id_block_number_index_index"
  @operation_type :create
  @table_columns ["address_id", "first_topic_id", "block_number", "index"]

  @impl HeavyDbIndexOperation
  def dependent_from_migrations,
    do: [
      CreateLogsAddressIdBlockNumberDescIndexDescIndex.migration_name()
    ]

  @impl HeavyDbIndexOperation
  def update_cache do
    BackgroundMigrations.set_heavy_indexes_create_logs_address_id_first_topic_id_block_number_index_index_finished(true)
  end
end
