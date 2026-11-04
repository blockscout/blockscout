# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Migrator.HeavyDbIndexOperation.DropTransactionsToAddressHashWithPendingIndex do
  @moduledoc """
  Drops index "transactions_to_address_hash_with_pending_index" btree (to_address_hash, block_number DESC, index DESC, inserted_at DESC, hash).
  """

  use Explorer.Migrator.HeavyDbIndexOperation

  alias Explorer.Chain.Cache.BackgroundMigrations
  alias Explorer.Migrator.HeavyDbIndexOperation

  alias Explorer.Migrator.HeavyDbIndexOperation.{
    DropTransactionsCreatedContractAddressHashWithPendingIndex,
    DropTransactionsFromAddressHashWithPendingIndex
  }

  @table_name :transactions
  @index_name "transactions_to_address_hash_with_pending_index"
  @operation_type :drop

  @impl HeavyDbIndexOperation
  def dependent_from_migrations,
    do: [
      DropTransactionsCreatedContractAddressHashWithPendingIndex.migration_name(),
      DropTransactionsFromAddressHashWithPendingIndex.migration_name()
    ]

  @impl HeavyDbIndexOperation
  def update_cache do
    BackgroundMigrations.set_heavy_indexes_drop_transactions_to_address_hash_with_pending_index_finished(true)
  end
end
