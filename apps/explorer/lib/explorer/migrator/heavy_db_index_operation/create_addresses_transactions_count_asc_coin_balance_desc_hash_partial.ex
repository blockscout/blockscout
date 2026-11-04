# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Migrator.HeavyDbIndexOperation.CreateAddressesTransactionsCountAscCoinBalanceDescHashPartialIndex do
  @moduledoc """
  Create partial B-tree index on `addresses` table filtering by `fetched_coin_balance > 0`
  and sorted by transactions_count ASC NULLS FIRST, fetched_coin_balance DESC, hash ASC.
  """

  use Explorer.Migrator.HeavyDbIndexOperation

  alias Explorer.Chain.Cache.BackgroundMigrations
  alias Explorer.Migrator.HeavyDbIndexOperation

  alias Explorer.Migrator.HeavyDbIndexOperation.{
    CreateAddressesTransactionsCountDescPartialIndex,
    CreateAddressesVerifiedFetchedCoinBalanceDescHashIndex
  }

  alias Explorer.Migrator.HeavyDbIndexOperation.Helper, as: HeavyDbIndexOperationHelper

  @table_name :addresses
  @index_name "addresses_transactions_count_asc_coin_balance_desc_hash_partial"
  @operation_type :create

  @impl HeavyDbIndexOperation
  def dependent_from_migrations,
    do: [
      CreateAddressesVerifiedFetchedCoinBalanceDescHashIndex.migration_name(),
      CreateAddressesTransactionsCountDescPartialIndex.migration_name()
    ]

  @query_string """
  CREATE INDEX #{HeavyDbIndexOperationHelper.add_concurrently_flag?()} IF NOT EXISTS "#{@index_name}"
  ON #{@table_name}(transactions_count ASC NULLS FIRST, fetched_coin_balance DESC, hash ASC)
  WHERE fetched_coin_balance > 0;
  """

  @impl HeavyDbIndexOperation
  def update_cache do
    BackgroundMigrations.set_heavy_indexes_create_addresses_transactions_count_asc_coin_balance_desc_hash_partial_index_finished(
      true
    )
  end
end
