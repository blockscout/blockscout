# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Migrator.HeavyDbIndexOperation.CreateLogsAddressIdFirstTopicIdSecondTopicBlockNumberIndex do
  @moduledoc """
  Create B-tree index `logs_address_id_first_topic_id_second_topic_block_number_index` on
  `logs` table for (`address_id`, `first_topic_id`, `second_topic`, `block_number`, `index`) columns.
  """

  use Explorer.Migrator.HeavyDbIndexOperation

  alias Explorer.Migrator.HeavyDbIndexOperation
  alias Explorer.Migrator.HeavyDbIndexOperation.CreateLogsAddressIdFirstTopicBlockNumberIndexIndex

  @table_name :logs
  @index_name "logs_address_id_first_topic_id_second_topic_block_number_index"
  @operation_type :create
  @table_columns ["address_id", "first_topic_id", "second_topic", "block_number", "index"]

  @impl HeavyDbIndexOperation
  def dependent_from_migrations,
    do: [
      CreateLogsAddressIdFirstTopicBlockNumberIndexIndex.migration_name()
    ]
end
