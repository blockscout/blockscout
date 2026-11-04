# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Migrator.HeavyDbIndexOperation.CreateTransactionsTokenTransferMethodIdOrderedIndex do
  @moduledoc """
  Create B-tree index `transactions_token_transfer_method_id_ordered_index` on `transactions`
  table for `SUBSTRING(input FROM 1 FOR 4)` ordered by `block_number desc, index desc` and only
  for transactions with `has_token_transfers = true`.
  """

  use Explorer.Migrator.HeavyDbIndexOperation

  alias Explorer.Chain.Cache.BackgroundMigrations
  alias Explorer.Migrator.{HeavyDbIndexOperation, TransactionHasTokenTransfers}
  alias Explorer.Migrator.HeavyDbIndexOperation.Helper, as: HeavyDbIndexOperationHelper

  @table_name :transactions
  @index_name "transactions_token_transfer_method_id_ordered_index"
  @operation_type :create
  @query_string """
  CREATE INDEX #{HeavyDbIndexOperationHelper.add_concurrently_flag?()} transactions_token_transfer_method_id_ordered_index
  ON transactions (SUBSTRING(input FROM 1 FOR 4), block_number DESC, index DESC) WHERE (has_token_transfers = TRUE);
  """

  @impl HeavyDbIndexOperation
  def dependent_from_migrations, do: [TransactionHasTokenTransfers.migration_name()]

  @impl HeavyDbIndexOperation
  def update_cache do
    BackgroundMigrations.set_heavy_indexes_create_transactions_token_transfer_method_id_ordered_index_finished(true)
  end
end
