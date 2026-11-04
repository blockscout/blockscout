# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Migrator.HeavyDbIndexOperation.DropTransactionsCreatedContractAddressHashWithPendingIndexA do
  @moduledoc """
  Drops index "transactions_created_contract_address_hash_with_pending_index_a" btree (created_contract_address_hash, block_number ASC NULLS LAST, index ASC NULLS LAST, inserted_at ASC, hash DESC).
  """

  use Explorer.Migrator.HeavyDbIndexOperation

  alias Explorer.Chain.Cache.BackgroundMigrations
  alias Explorer.Migrator.HeavyDbIndexOperation
  alias Explorer.Migrator.HeavyDbIndexOperation.CreateTransactionsCreatedContractAddressHashWPendingIndex

  @table_name :transactions
  @index_name "transactions_created_contract_address_hash_with_pending_index_a"
  @operation_type :drop

  @impl HeavyDbIndexOperation
  def dependent_from_migrations do
    [CreateTransactionsCreatedContractAddressHashWPendingIndex.migration_name()]
  end

  @impl HeavyDbIndexOperation
  def update_cache do
    BackgroundMigrations.set_heavy_indexes_drop_transactions_created_contract_address_hash_with_pending_index_a_finished(
      true
    )
  end
end
