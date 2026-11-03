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

  alias Explorer.Migrator.{HeavyDbIndexOperation, MigrationStatus}
  alias Explorer.Migrator.HeavyDbIndexOperation.CreateArbitrumBatchL2BlocksUnconfirmedBlocksIndex
  alias Explorer.Migrator.HeavyDbIndexOperation.Helper, as: HeavyDbIndexOperationHelper

  @table_name :arbitrum_batch_l2_blocks
  @index_name "arbitrum_batch_l2_blocks_unconfirmed_blocks_index"
  @operation_type :drop

  @impl HeavyDbIndexOperation
  def table_name, do: @table_name

  @impl HeavyDbIndexOperation
  def operation_type, do: @operation_type

  @impl HeavyDbIndexOperation
  def index_name, do: @index_name

  @impl HeavyDbIndexOperation
  def dependent_from_migrations, do: [CreateArbitrumBatchL2BlocksUnconfirmedBlocksIndex.migration_name()]

  @impl HeavyDbIndexOperation
  def db_index_operation do
    HeavyDbIndexOperationHelper.safely_drop_db_index(@index_name)
  end

  @impl HeavyDbIndexOperation
  def check_db_index_operation_progress do
    operation = HeavyDbIndexOperationHelper.drop_index_query_string(@index_name)
    HeavyDbIndexOperationHelper.check_db_index_operation_progress(@index_name, operation)
  end

  @impl HeavyDbIndexOperation
  def db_index_operation_status do
    HeavyDbIndexOperationHelper.db_index_dropping_status(@index_name)
  end

  @impl HeavyDbIndexOperation
  def restart_db_index_operation do
    HeavyDbIndexOperationHelper.safely_drop_db_index(@index_name)
  end

  @impl HeavyDbIndexOperation
  def running_other_heavy_migration_exists?(migration_name) do
    MigrationStatus.running_other_heavy_migration_for_table_exists?(@table_name, migration_name)
  end

  @impl HeavyDbIndexOperation
  def update_cache, do: :ok
end
