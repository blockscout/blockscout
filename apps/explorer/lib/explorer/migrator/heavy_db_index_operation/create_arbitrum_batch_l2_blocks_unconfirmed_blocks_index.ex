# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Migrator.HeavyDbIndexOperation.CreateArbitrumBatchL2BlocksUnconfirmedBlocksIndex do
  @moduledoc """
  Create partial B-tree index on `arbitrum_batch_l2_blocks` table filtering by `confirmation_id IS NULL`.
  """

  use Explorer.Migrator.HeavyDbIndexOperation

  alias Explorer.Chain.Cache.BackgroundMigrations
  alias Explorer.Migrator.HeavyDbIndexOperation
  alias Explorer.Migrator.HeavyDbIndexOperation.Helper, as: HeavyDbIndexOperationHelper

  @table_name :arbitrum_batch_l2_blocks
  @index_name "arbitrum_batch_l2_blocks_unconfirmed_blocks_index"
  @operation_type :create

  @query_string """
  CREATE INDEX #{HeavyDbIndexOperationHelper.add_concurrently_flag?()} IF NOT EXISTS #{@index_name}
  ON #{@table_name} (confirmation_id, block_number DESC)
  WHERE confirmation_id IS NULL;
  """

  @impl HeavyDbIndexOperation
  def update_cache do
    BackgroundMigrations.set_heavy_indexes_create_arbitrum_batch_l2_blocks_unconfirmed_blocks_index_finished(true)
  end
end
