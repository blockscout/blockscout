defmodule Explorer.Migrator.HeavyDbIndexOperation.DropTokenTransfersToAddressHashTransactionHashIndex do
  @moduledoc """
  Drops index "token_transfers_to_address_hash_transaction_hash_index" btree (to_address_hash, transaction_hash).
  """

  use Explorer.Migrator.HeavyDbIndexOperation

  alias Explorer.Chain.Cache.BackgroundMigrations
  alias Explorer.Migrator.HeavyDbIndexOperation
  alias Explorer.Migrator.HeavyDbIndexOperation.Helper, as: HeavyDbIndexOperationHelper

  @migration_name "heavy_indexes_drop_token_transfers_to_address_hash_transaction_hash_index"
  @index_name "token_transfers_to_address_hash_transaction_hash_index"
  @dependent_from_migrations [
    "heavy_indexes_drop_token_transfers_block_number_asc_log_index_asc_index",
    "heavy_indexes_drop_token_transfers_from_address_hash_transaction_hash_index"
  ]

  @impl HeavyDbIndexOperation
  def migration_name, do: @migration_name

  @impl HeavyDbIndexOperation
  def dependent_from_migrations do
    @dependent_from_migrations
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
    BackgroundMigrations.set_heavy_indexes_drop_token_transfers_to_address_hash_transaction_hash_index_finished(true)
  end
end
