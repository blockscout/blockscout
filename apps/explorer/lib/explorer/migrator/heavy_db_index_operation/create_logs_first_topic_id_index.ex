# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Migrator.HeavyDbIndexOperation.CreateLogsFirstTopicIdIndex do
  @moduledoc """
  Create B-tree index on `logs` table for `first_topic_id` column.
  """

  use Explorer.Migrator.HeavyDbIndexOperation

  alias Explorer.Chain.Cache.BackgroundMigrations
  alias Explorer.Migrator.HeavyDbIndexOperation
  alias Explorer.Migrator.HeavyDbIndexOperation.CreateLogsAddressIdFirstTopicIdSecondTopicBlockNumberIndex

  @table_name :logs
  @index_name "logs_first_topic_id_index"
  @operation_type :create
  @table_columns ["first_topic_id"]

  @impl HeavyDbIndexOperation
  def dependent_from_migrations,
    do: [
      CreateLogsAddressIdFirstTopicIdSecondTopicBlockNumberIndex.migration_name()
    ]

  @impl HeavyDbIndexOperation
  def update_cache do
    BackgroundMigrations.set_create_logs_first_topic_id_index_finished(true)
  end
end
