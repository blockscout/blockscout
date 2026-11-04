# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Migrator.HeavyDbIndexOperation.CreateAddressCurrentTokenBalancesAddressHashBlockNumberIndex do
  @moduledoc """
  Create B-tree index `address_current_token_balances_address_hash_block_number_index` on
  `address_current_token_balances` table for (`address_hash`, `block_number`) columns.
  """

  use Explorer.Migrator.HeavyDbIndexOperation

  alias Explorer.Chain.Cache.BackgroundMigrations
  alias Explorer.Migrator.HeavyDbIndexOperation

  @table_name :address_current_token_balances
  @index_name "address_current_token_balances_address_hash_block_number_index"
  @operation_type :create
  @table_columns ["address_hash", "block_number"]

  @impl HeavyDbIndexOperation
  def update_cache do
    BackgroundMigrations.set_heavy_indexes_create_address_current_token_balances_address_hash_block_number_index_finished(
      true
    )
  end
end
