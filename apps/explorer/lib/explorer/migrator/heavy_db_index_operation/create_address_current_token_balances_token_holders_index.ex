# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Migrator.HeavyDbIndexOperation.CreateAddressCurrentTokenBalancesTokenHoldersIndex do
  @moduledoc """
  Create partial B-tree index on `address_current_token_balances` table for the
  token holders queries: `(token_contract_address_hash, value DESC, address_hash DESC)`
  filtered by `address_hash != burn address AND (value > 0 OR token_type = 'ERC-7984')`.

  Replaces "address_current_token_balances_token_contract_address_hash__val"
  (same columns, but predicate `value > 0` only; the name may differ on
  instances where the index was created manually): after the
  `OR token_type = 'ERC-7984'` disjunct was added to the token holders queries
  for confidential tokens support, their predicate stopped implying the old
  index's predicate, making the old partial index unusable for them and forcing
  a sorted scan over a non-partial fallback index. The predicate here matches
  the queries verbatim, and queries filtering by plain `value > 0` can use it
  as well (`value > 0` implies the disjunction).
  """

  use Explorer.Migrator.HeavyDbIndexOperation

  alias Explorer.Migrator.{HeavyDbIndexOperation, MigrationStatus}
  alias Explorer.Migrator.HeavyDbIndexOperation.Helper, as: HeavyDbIndexOperationHelper

  @table_name :address_current_token_balances
  @index_name "address_current_token_balances_token_holders_index"
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
  ON #{@table_name} (token_contract_address_hash, value DESC, address_hash DESC)
  WHERE address_hash != '\\x0000000000000000000000000000000000000000' AND (value > 0 OR token_type = 'ERC-7984');
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
