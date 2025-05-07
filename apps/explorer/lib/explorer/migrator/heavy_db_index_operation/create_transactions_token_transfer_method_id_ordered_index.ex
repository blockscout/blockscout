defmodule Explorer.Migrator.HeavyDbIndexOperation.CreateTransactionsTokenTransferMethodIdOrderedIndex do
  @moduledoc """
  Create B-tree index `transactions_token_transfer_method_id_ordered_index` on `transactions`
  table for `SUBSTRING(input FROM 1 FOR 4)` ordered by `block_number desc, index desc` and only
  for transactions with `has_token_transfers = true`.
  """

  use Explorer.Migrator.HeavyDbIndexOperation

  alias Explorer.Chain.Cache.BackgroundMigrations
  alias Explorer.Migrator.{HeavyDbIndexOperation, MigrationStatus}
  alias Explorer.Migrator.HeavyDbIndexOperation.Helper, as: HeavyDbIndexOperationHelper

  @table_name :transactions
  @index_name "transactions_token_transfer_method_id_ordered_index"
  @operation_type :create
  @query_string """
  CREATE INDEX #{HeavyDbIndexOperationHelper.add_concurrently_flag?()} transactions_token_transfer_method_id_ordered_index
  ON transactions (SUBSTRING(input FROM 1 FOR 4), block_number DESC, index DESC) WHERE (has_token_transfers = TRUE);
  """

  @impl HeavyDbIndexOperation
  def table_name, do: @table_name

  @impl HeavyDbIndexOperation
  def operation_type, do: @operation_type

  @impl HeavyDbIndexOperation
  def index_name, do: @index_name

  @impl HeavyDbIndexOperation
  def dependent_from_migrations, do: []

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
    BackgroundMigrations.set_heavy_indexes_create_transactions_token_transfer_method_id_ordered_index_finished(true)
  end
end
