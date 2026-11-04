# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Migrator.HeavyDbIndexOperation.CreateInternalTransactionsBlockNumberDescTransactionIndexDescIndexDescIndex do
  @moduledoc """
  Create B-tree index `internal_transactions_block_number_DESC_transaction_index_DESC_index_DESC_index` on `internal_transactions` table for (`block_number` DESC, `transaction_index` DESC, `index` DESC) columns.
  """

  use Explorer.Migrator.HeavyDbIndexOperation

  alias Explorer.Chain.Cache.BackgroundMigrations
  alias Explorer.Migrator.HeavyDbIndexOperation
  alias Explorer.Migrator.HeavyDbIndexOperation.DropInternalTransactionsFromAddressHashIndex

  @table_name :internal_transactions
  @index_name "internal_transactions_block_number_DESC_transaction_index_DESC_index_DESC_index"
  @operation_type :create
  @table_columns ["block_number DESC", "transaction_index DESC", "index DESC"]

  @impl HeavyDbIndexOperation
  def dependent_from_migrations,
    do: [
      DropInternalTransactionsFromAddressHashIndex.migration_name()
    ]

  @impl HeavyDbIndexOperation
  def update_cache do
    BackgroundMigrations.set_heavy_indexes_create_internal_transactions_block_number_desc_transaction_index_desc_index_desc_index_finished(
      true
    )
  end
end
