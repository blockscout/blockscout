defmodule Explorer.Migrator.HeavyDbIndexOperation.CreateTokensOrdFiatHolderNameIndex do
  @moduledoc """
  Create B-tree index `idx_tokens_ord_fiat_holder_name` on `tokens` table for
  (`fiat_value DESC NULLS LAST`, `holder_count DESC NULLS LAST`, `name`).
  """

  use Explorer.Migrator.HeavyDbIndexOperation

  require Logger

  alias Explorer.Chain.Cache.BackgroundMigrations
  alias Explorer.Migrator.{HeavyDbIndexOperation, MigrationStatus}
  alias Explorer.Migrator.HeavyDbIndexOperation.CreateTokensOrdMcapFiatHolderNameIndex
  alias Explorer.Migrator.HeavyDbIndexOperation.Helper, as: HeavyDbIndexOperationHelper

  @table_name :tokens
  @index_name "idx_tokens_ord_fiat_holder_name"
  @operation_type :create
  @table_columns [
    "fiat_value DESC NULLS LAST",
    "holder_count DESC NULLS LAST",
    "name"
  ]

  @impl HeavyDbIndexOperation
  def table_name, do: @table_name

  @impl HeavyDbIndexOperation
  def operation_type, do: @operation_type

  @impl HeavyDbIndexOperation
  def index_name, do: @index_name

  @impl HeavyDbIndexOperation
  def dependent_from_migrations do
    [CreateTokensOrdMcapFiatHolderNameIndex.migration_name()]
  end

  @impl HeavyDbIndexOperation
  def db_index_operation do
    HeavyDbIndexOperationHelper.create_db_index(@index_name, @table_name, @table_columns)
  end

  @impl HeavyDbIndexOperation
  def check_db_index_operation_progress do
    operation = HeavyDbIndexOperationHelper.create_index_query_string(@index_name, @table_name, @table_columns)
    HeavyDbIndexOperationHelper.check_db_index_operation_progress(@index_name, operation)
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
    BackgroundMigrations.set_heavy_indexes_create_idx_tokens_ord_fiat_holder_name_finished(true)
  end
end
