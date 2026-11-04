# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Migrator.HeavyDbIndexOperation.DropUnfetchedAddressTokenBalancesV2Index do
  @moduledoc """
  Drop the second version of the partial B-tree index on `address_token_balances`
  serving `Explorer.Chain.Address.TokenBalance.unfetched_token_balances/0`.

  Its predicate lists neither ERC-8056 nor ZRC-2, so the query no longer implies
  it and the planner cannot use it — it only takes up space and slows writes.

  Waits for
  `Explorer.Migrator.HeavyDbIndexOperation.CreateUnfetchedAddressTokenBalancesV3Index`,
  so the queries are served by the replacement before this one goes away.
  """

  use Explorer.Migrator.HeavyDbIndexOperation

  alias Explorer.Migrator.HeavyDbIndexOperation
  alias Explorer.Migrator.HeavyDbIndexOperation.CreateUnfetchedAddressTokenBalancesV3Index

  @table_name :address_token_balances
  @index_name "unfetched_address_token_balances_v2_index"
  @operation_type :drop

  @impl HeavyDbIndexOperation
  def dependent_from_migrations,
    do: [
      CreateUnfetchedAddressTokenBalancesV3Index.migration_name()
    ]
end
