# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Migrator.HeavyDbIndexOperation.DropTokenTransfersBlockNumberAscLogIndexAscIndex do
  @moduledoc """
  Drops index "token_transfers_block_number_ASC_log_index_ASC_index" btree (block_number, log_index).
  """

  use Explorer.Migrator.HeavyDbIndexOperation

  alias Explorer.Chain.Cache.BackgroundMigrations
  alias Explorer.Migrator.HeavyDbIndexOperation

  @table_name :token_transfers
  @index_name "token_transfers_block_number_ASC_log_index_ASC_index"
  @operation_type :drop

  @impl HeavyDbIndexOperation
  def dependent_from_migrations do
    []
  end

  @impl HeavyDbIndexOperation
  def update_cache do
    BackgroundMigrations.set_heavy_indexes_drop_token_transfers_block_number_asc_log_index_asc_index_finished(true)
  end
end
