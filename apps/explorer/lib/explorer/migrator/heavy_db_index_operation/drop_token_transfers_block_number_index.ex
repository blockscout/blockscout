# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Migrator.HeavyDbIndexOperation.DropTokenTransfersBlockNumberIndex do
  @moduledoc """
  Drops index "token_transfers_block_number_index" btree (block_number).
  """

  use Explorer.Migrator.HeavyDbIndexOperation

  alias Explorer.Chain.Cache.BackgroundMigrations
  alias Explorer.Migrator.HeavyDbIndexOperation

  alias Explorer.Migrator.HeavyDbIndexOperation.{
    DropTokenTransfersBlockNumberAscLogIndexAscIndex,
    DropTokenTransfersFromAddressHashTransactionHashIndex,
    DropTokenTransfersToAddressHashTransactionHashIndex,
    DropTokenTransfersTokenContractAddressHashTransactionHashIndex
  }

  @table_name :token_transfers
  @index_name "token_transfers_block_number_index"
  @operation_type :drop

  @impl HeavyDbIndexOperation
  def dependent_from_migrations,
    do: [
      DropTokenTransfersBlockNumberAscLogIndexAscIndex.migration_name(),
      DropTokenTransfersFromAddressHashTransactionHashIndex.migration_name(),
      DropTokenTransfersToAddressHashTransactionHashIndex.migration_name(),
      DropTokenTransfersTokenContractAddressHashTransactionHashIndex.migration_name()
    ]

  @impl HeavyDbIndexOperation
  def update_cache do
    BackgroundMigrations.set_heavy_indexes_drop_token_transfers_block_number_index_finished(true)
  end
end
