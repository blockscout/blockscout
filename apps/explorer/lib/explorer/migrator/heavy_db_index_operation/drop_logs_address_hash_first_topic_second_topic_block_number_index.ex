# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Migrator.HeavyDbIndexOperation.DropLogsAddressHashFirstTopicSecondTopicBlockNumberIndex do
  @moduledoc """
  Drops B-tree index `logs_address_hash_first_topic_second_topic_block_number_index` on `logs` table for
  (`address_hash`, `first_topic`, `second_topic`, `block_number`, `index`) columns.

  The index is superseded by `logs_address_id_first_topic_id_second_topic_block_number_index` once
  `address_hash` and `first_topic` are replaced with `address_id` and `first_topic_id`.
  """

  use Explorer.Migrator.HeavyDbIndexOperation

  alias Explorer.Migrator.{FillLogsOptimizedFields, HeavyDbIndexOperation}

  alias Explorer.Migrator.HeavyDbIndexOperation.{
    CreateLogsAddressHashFirstTopicSecondTopicBlockNumberIndex,
    CreateLogsAddressIdFirstTopicIdSecondTopicBlockNumberIndex,
    DropLogsAddressHashFirstTopicBlockNumberIndexIndex
  }

  @table_name :logs
  @index_name "logs_address_hash_first_topic_second_topic_block_number_index"
  @operation_type :drop

  # The create migration of this very index is a dependency too: otherwise the drop could complete while the
  # creation has not started yet or is being retried after an invalid build, and the index would be rebuilt afterwards.
  @impl HeavyDbIndexOperation
  def dependent_from_migrations,
    do: [
      CreateLogsAddressHashFirstTopicSecondTopicBlockNumberIndex.migration_name(),
      FillLogsOptimizedFields.migration_name(),
      CreateLogsAddressIdFirstTopicIdSecondTopicBlockNumberIndex.migration_name(),
      DropLogsAddressHashFirstTopicBlockNumberIndexIndex.migration_name()
    ]
end
