# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Migrator.HeavyDbIndexOperation.DropTransactionsCreatedContractAddressHashWithPendingIndex do
  @moduledoc """
  Drops index "transactions_created_contract_address_hash_with_pending_index" btree (created_contract_address_hash, block_number DESC, index DESC, inserted_at DESC, hash).
  """

  use Explorer.Migrator.HeavyDbIndexOperation

  alias Explorer.Chain.Cache.BackgroundMigrations
  alias Explorer.Migrator.HeavyDbIndexOperation

  @table_name :transactions
  @index_name "transactions_created_contract_address_hash_with_pending_index"
  @operation_type :drop

  @impl HeavyDbIndexOperation
  def update_cache do
    BackgroundMigrations.set_heavy_indexes_drop_transactions_created_contract_address_hash_with_pending_index_finished(
      true
    )
  end
end
