# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Migrator.HeavyDbIndexOperation.CreateAddressesVerifiedTransactionsCountDescHashIndex do
  @moduledoc """
  Create partial B-tree index on `addresses` table filtering by `verified=true`
  and sorted by transactions_count DESC, hash ASC.
  """

  use Explorer.Migrator.HeavyDbIndexOperation

  alias Explorer.Chain.Cache.BackgroundMigrations
  alias Explorer.Migrator.HeavyDbIndexOperation
  alias Explorer.Migrator.HeavyDbIndexOperation.CreateAddressesVerifiedHashIndex
  alias Explorer.Migrator.HeavyDbIndexOperation.Helper, as: HeavyDbIndexOperationHelper

  @table_name :addresses
  @index_name "addresses_verified_transactions_count_DESC_hash_index"
  @operation_type :create

  @impl HeavyDbIndexOperation
  def dependent_from_migrations,
    do: [
      CreateAddressesVerifiedHashIndex.migration_name()
    ]

  @query_string """
  CREATE INDEX #{HeavyDbIndexOperationHelper.add_concurrently_flag?()} IF NOT EXISTS "#{@index_name}"
  ON #{@table_name}(transactions_count DESC NULLS LAST, hash ASC)
  WHERE verified = true;
  """

  @impl HeavyDbIndexOperation
  def update_cache do
    BackgroundMigrations.set_heavy_indexes_create_addresses_verified_transactions_count_desc_hash_index_finished(true)
  end
end
