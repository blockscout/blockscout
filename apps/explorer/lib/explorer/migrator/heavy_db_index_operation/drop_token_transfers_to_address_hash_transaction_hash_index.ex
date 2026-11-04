# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Migrator.HeavyDbIndexOperation.DropTokenTransfersToAddressHashTransactionHashIndex do
  @moduledoc """
  Drops index "token_transfers_to_address_hash_transaction_hash_index" btree (to_address_hash, transaction_hash).
  """

  use Explorer.Migrator.HeavyDbIndexOperation

  alias Explorer.Chain.Cache.BackgroundMigrations
  alias Explorer.Migrator.HeavyDbIndexOperation

  alias Explorer.Migrator.HeavyDbIndexOperation.{
    DropTokenTransfersBlockNumberAscLogIndexAscIndex,
    DropTokenTransfersFromAddressHashTransactionHashIndex
  }

  @table_name :token_transfers
  @index_name "token_transfers_to_address_hash_transaction_hash_index"
  @operation_type :drop

  @impl HeavyDbIndexOperation
  def dependent_from_migrations,
    do: [
      DropTokenTransfersBlockNumberAscLogIndexAscIndex.migration_name(),
      DropTokenTransfersFromAddressHashTransactionHashIndex.migration_name()
    ]

  @impl HeavyDbIndexOperation
  def update_cache do
    BackgroundMigrations.set_heavy_indexes_drop_token_transfers_to_address_hash_transaction_hash_index_finished(true)
  end
end
