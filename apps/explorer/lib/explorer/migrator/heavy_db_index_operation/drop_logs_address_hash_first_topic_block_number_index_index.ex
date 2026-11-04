# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Migrator.HeavyDbIndexOperation.DropLogsAddressHashFirstTopicBlockNumberIndexIndex do
  @moduledoc """
  Drops B-tree index `logs_address_hash_first_topic_block_number_index_index` on `logs` table for (`address_hash`, `first_topic`, `block_number`, `index`) columns.
  """

  use Explorer.Migrator.HeavyDbIndexOperation

  alias Explorer.Migrator.{FillLogsOptimizedFields, HeavyDbIndexOperation}
  alias Explorer.Migrator.HeavyDbIndexOperation.DropLogsAddressHashBlockNumberDescIndexDescIndex

  @table_name :logs
  @index_name "logs_address_hash_first_topic_block_number_index_index"
  @operation_type :drop

  @impl HeavyDbIndexOperation
  def dependent_from_migrations,
    do: [
      FillLogsOptimizedFields.migration_name(),
      DropLogsAddressHashBlockNumberDescIndexDescIndex.migration_name()
    ]
end
