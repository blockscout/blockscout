# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Migrator.HeavyDbIndexOperation.DropInternalTransactionsFromAddressHashIndex do
  @moduledoc """
  Drops index "internal_transactions_from_address_hash_index" btree (from_address_hash).
  """

  use Explorer.Migrator.HeavyDbIndexOperation

  alias Explorer.Chain.Cache.BackgroundMigrations
  alias Explorer.Migrator.HeavyDbIndexOperation

  @table_name :internal_transactions
  @index_name "internal_transactions_from_address_hash_index"
  @operation_type :drop

  @impl HeavyDbIndexOperation
  def dependent_from_migrations do
    []
  end

  @impl HeavyDbIndexOperation
  def update_cache do
    BackgroundMigrations.set_heavy_indexes_drop_internal_transactions_from_address_hash_index_finished(true)
  end
end
