# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Migrator.HeavyDbIndexOperation.CreateInternalTransactionsBlockNumberTransactionIndexIndexUniqueIndex do
  @moduledoc """
  Create unique B-tree index `internal_transactions_block_number_transaction_index_index_index` on `internal_transactions` table for (`block_number`, `transaction_index`, `index`) columns.
  """

  use Explorer.Migrator.HeavyDbIndexOperation

  alias Explorer.Migrator.{EmptyInternalTransactionsData, HeavyDbIndexOperation}

  @table_name :internal_transactions
  @index_name "internal_transactions_block_number_transaction_index_index_index"
  @operation_type :create
  @table_columns ["block_number", "transaction_index", "index"]
  @unique_index true

  @impl HeavyDbIndexOperation
  def dependent_from_migrations,
    do: [
      EmptyInternalTransactionsData.migration_name()
    ]
end
