# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Migrator.HeavyDbIndexOperation.CreateUnfetchedAddressTokenBalancesV3Index do
  @moduledoc """
  Create the third version of the partial B-tree index on `address_token_balances`
  serving `Explorer.Chain.Address.TokenBalance.unfetched_token_balances/0`.

  A partial index is only usable when the query's predicate implies the index's,
  so the predicate has to list every token type that query accepts. The `v2`
  index this one replaces predates ERC-8056 — and ZRC-2, which the Zilliqa
  variant of the query has always asked for — which would make the planner drop
  the index and fall back to a sequential scan of the table.

  Listing a type the query does not ask for is harmless the other way round: the
  index simply holds a few rows that get filtered out afterwards. That is why one
  predicate covers both the Zilliqa and the ordinary shape of the query.

  `refetch_after < now()` stays out of the predicate: it is not immutable and
  cannot appear in one. Filtering it out of the far smaller set of rows the index
  yields is cheap.

  The `v2` index is removed by
  `Explorer.Migrator.HeavyDbIndexOperation.DropUnfetchedAddressTokenBalancesV2Index`
  once this one is in place, which keeps the queries served throughout — the same
  create-then-drop sequence the `v1` to `v2` replacement used.
  """

  use Explorer.Migrator.HeavyDbIndexOperation

  require Logger

  alias Explorer.Migrator.{HeavyDbIndexOperation, MigrationStatus}
  alias Explorer.Migrator.HeavyDbIndexOperation.Helper, as: HeavyDbIndexOperationHelper

  @table_name :address_token_balances
  @index_name "unfetched_address_token_balances_v3_index"
  @operation_type :create

  @impl HeavyDbIndexOperation
  def table_name, do: @table_name

  @impl HeavyDbIndexOperation
  def operation_type, do: @operation_type

  @impl HeavyDbIndexOperation
  def index_name, do: @index_name

  @impl HeavyDbIndexOperation
  def dependent_from_migrations, do: []

  @query_string """
  CREATE INDEX #{HeavyDbIndexOperationHelper.add_concurrently_flag?()} IF NOT EXISTS "#{@index_name}"
  ON #{@table_name}(id)
  WHERE ((address_hash != '\\x0000000000000000000000000000000000000000' AND token_type = 'ERC-721')
         OR token_type IN ('ERC-20', 'ERC-8056', 'ZRC-2', 'ERC-1155', 'ERC-404'))
    AND (value_fetched_at IS NULL OR value IS NULL);
  """

  @impl HeavyDbIndexOperation
  def db_index_operation do
    HeavyDbIndexOperationHelper.create_db_index(@query_string)
  end

  @impl HeavyDbIndexOperation
  def check_db_index_operation_progress do
    HeavyDbIndexOperationHelper.check_db_index_operation_progress(@index_name, @query_string)
  end

  @impl HeavyDbIndexOperation
  def db_index_operation_status do
    HeavyDbIndexOperationHelper.db_index_creation_status(@index_name)
  end

  @impl HeavyDbIndexOperation
  def restart_db_index_operation do
    HeavyDbIndexOperationHelper.safely_drop_db_index(@index_name)
  end

  @impl HeavyDbIndexOperation
  def running_other_heavy_migration_exists?(migration_name) do
    MigrationStatus.running_other_heavy_migration_for_table_exists?(@table_name, migration_name)
  end

  @impl HeavyDbIndexOperation
  def update_cache, do: :ok
end
