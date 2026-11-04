# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Migrator.HeavyDbIndexOperation.DropLogsBlockNumberAscIndexAscIndex do
  @moduledoc """
  Drops index "logs_block_number_ASC__index_ASC_index" btree (block_number, index).
  """

  use Explorer.Migrator.HeavyDbIndexOperation

  alias Explorer.Chain.Cache.BackgroundMigrations
  alias Explorer.Migrator.HeavyDbIndexOperation

  @table_name :logs
  @index_name "logs_block_number_ASC__index_ASC_index"
  @operation_type :drop

  @impl HeavyDbIndexOperation
  def dependent_from_migrations do
    []
  end

  @impl HeavyDbIndexOperation
  def update_cache do
    BackgroundMigrations.set_heavy_indexes_drop_logs_block_number_asc_index_asc_index_finished(true)
  end
end
