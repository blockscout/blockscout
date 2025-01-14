defmodule Explorer.Migrator.HeavyDbIndexOperation.DropInternalTransactionsFromAddressHashIndex do
  @moduledoc """
  Drops index "internal_transactions_from_address_hash_index" btree (from_address_hash).
  """

  use Explorer.Migrator.HeavyDbIndexOperation

  alias Explorer.Chain.Cache.BackgroundMigrations
  alias Explorer.Migrator.HeavyDbIndexOperation
  alias Explorer.Migrator.HeavyDbIndexOperation.Helper, as: HeavyDbIndexOperationHelper

  @migration_name "heavy_indexes_drop_internal_transactions_from_address_hash_index"
  @index_name "internal_transactions_from_address_hash_index"

  @impl HeavyDbIndexOperation
  def migration_name, do: @migration_name

  @impl HeavyDbIndexOperation
  def dependent_from_migrations do
    []
  end

  @impl HeavyDbIndexOperation
  def db_index_operation do
    HeavyDbIndexOperationHelper.safely_drop_db_index(@index_name)
  end

  @impl HeavyDbIndexOperation
  def check_db_index_operation_progress do
    HeavyDbIndexOperationHelper.check_db_index_dropping_progress(@index_name)
  end

  @impl HeavyDbIndexOperation
  def db_index_operation_status do
    HeavyDbIndexOperationHelper.db_index_dropping_status(@index_name)
  end

  @impl HeavyDbIndexOperation
  def complete_db_index_operation do
    :error
  end

  @impl HeavyDbIndexOperation
  def update_cache do
    BackgroundMigrations.set_heavy_indexes_drop_internal_transactions_from_address_hash_index_finished(true)
  end
end
