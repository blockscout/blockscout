# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Migrator.HeavyDbIndexOperation.DropInternalTransactionsCreatedContractAddressHashPartialIndex do
  @moduledoc """
  Drops index "internal_transactions_created_contract_address_hash_partial_index" on internal_transactions(created_contract_address_hash, block_number DESC, transaction_index DESC, index DESC).
  """

  use Explorer.Migrator.HeavyDbIndexOperation

  alias Explorer.Chain.Cache.BackgroundMigrations
  alias Explorer.Migrator.{EmptyInternalTransactionsData, HeavyDbIndexOperation}

  @table_name :internal_transactions
  @index_name "internal_transactions_created_contract_address_hash_partial_index"
  @operation_type :drop

  @impl HeavyDbIndexOperation
  def dependent_from_migrations do
    [EmptyInternalTransactionsData.migration_name()]
  end

  @impl HeavyDbIndexOperation
  def update_cache do
    BackgroundMigrations.set_heavy_indexes_drop_internal_transactions_created_contract_address_hash_partial_index_finished(
      true
    )
  end
end
