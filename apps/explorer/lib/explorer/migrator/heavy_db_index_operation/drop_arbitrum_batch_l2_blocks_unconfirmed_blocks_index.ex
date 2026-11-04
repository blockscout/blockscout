# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Migrator.HeavyDbIndexOperation.DropArbitrumBatchL2BlocksUnconfirmedBlocksIndex do
  @moduledoc """
  Drops the partial index `arbitrum_batch_l2_blocks_unconfirmed_blocks_index` on
  `arbitrum_batch_l2_blocks` (`confirmation_id`, `block_number DESC`) `WHERE confirmation_id IS NULL`.

  The confirmations of rollup blocks live in `arbitrum_rollup_block_confirmations`.
  No code reads `confirmation_id` of `arbitrum_batch_l2_blocks` any more. The
  migration waits for `CreateArbitrumBatchL2BlocksUnconfirmedBlocksIndex`, so that
  it does not start while the creation of the index continues on an instance.
  """

  use Explorer.Migrator.HeavyDbIndexOperation

  alias Explorer.Migrator.HeavyDbIndexOperation
  alias Explorer.Migrator.HeavyDbIndexOperation.CreateArbitrumBatchL2BlocksUnconfirmedBlocksIndex

  @table_name :arbitrum_batch_l2_blocks
  @index_name "arbitrum_batch_l2_blocks_unconfirmed_blocks_index"
  @operation_type :drop

  @impl HeavyDbIndexOperation
  def dependent_from_migrations, do: [CreateArbitrumBatchL2BlocksUnconfirmedBlocksIndex.migration_name()]
end
