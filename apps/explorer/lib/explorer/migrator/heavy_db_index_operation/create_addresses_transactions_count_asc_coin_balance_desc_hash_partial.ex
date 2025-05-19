defmodule Explorer.Migrator.HeavyDbIndexOperation.CreateAddressesTransactionsCountAscCoinBalanceDescHashPartialIndex do
  @moduledoc """
  Create partial B-tree index on `addresses` table filtering by `fetched_coin_balance > 0`
  and sorted by transactions_count ASC NULLS FIRST, fetched_coin_balance DESC, hash ASC.
  """

  use Explorer.Migrator.HeavyDbIndexOperation

  require Logger

  alias Explorer.Chain.Cache.BackgroundMigrations
  alias Explorer.Migrator.{HeavyDbIndexOperation, MigrationStatus}

  alias Explorer.Migrator.HeavyDbIndexOperation.{
    CreateAddressesTransactionsCountDescPartialIndex,
    CreateAddressesVerifiedFetchedCoinBalanceDescHashIndex
  }

  alias Explorer.Migrator.HeavyDbIndexOperation.Helper, as: HeavyDbIndexOperationHelper

  @table_name :addresses
  @index_name "addresses_transactions_count_asc_coin_balance_desc_hash_partial"
  @operation_type :create

  @impl HeavyDbIndexOperation
  def table_name, do: @table_name

  @impl HeavyDbIndexOperation
  def operation_type, do: @operation_type

  @impl HeavyDbIndexOperation
  def index_name, do: @index_name

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
  def update_cache do
    BackgroundMigrations.set_heavy_indexes_create_addresses_transactions_count_asc_coin_balance_desc_hash_partial_index_finished(
      true
    )
  end
end
