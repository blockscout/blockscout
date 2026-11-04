# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Migrator.HeavyDbIndexOperation.CreateLogsAddressHashFirstTopicSecondTopicBlockNumberIndex do
  @moduledoc """
  Create B-tree index `logs_address_hash_first_topic_second_topic_block_number_index` on
  `logs` table for (`address_hash`, `first_topic`, `second_topic`, `block_number`, `index`) columns.
  """

  use Explorer.Migrator.HeavyDbIndexOperation

  alias Explorer.Chain.Cache.BackgroundMigrations
  alias Explorer.Migrator.HeavyDbIndexOperation

  @table_name :logs
  @index_name "logs_address_hash_first_topic_second_topic_block_number_index"
  @operation_type :create
  @table_columns ["address_hash", "first_topic", "second_topic", "block_number", "index"]

  @impl HeavyDbIndexOperation
  def update_cache do
    BackgroundMigrations.set_heavy_indexes_create_logs_address_hash_first_topic_second_topic_block_number_index_finished(
      true
    )
  end
end
