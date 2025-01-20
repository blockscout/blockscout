defmodule Explorer.Migrator.HeavyDbIndexOperation.DropLogsBlockNumberAscIndexAscIndex do
  @moduledoc """
  Drops index "logs_block_number_ASC__index_ASC_index" btree (block_number, index).
  """

  use Explorer.Migrator.HeavyDbIndexOperation

  alias Explorer.Chain.Cache.BackgroundMigrations
  alias Explorer.Migrator.HeavyDbIndexOperation
  alias Explorer.Migrator.HeavyDbIndexOperation.Helper, as: HeavyDbIndexOperationHelper

  @migration_name "heavy_indexes_drop_logs_block_number_asc_index_asc_index"
  @index_name "logs_block_number_ASC__index_ASC_index"

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
  def restart_db_index_operation do
    HeavyDbIndexOperationHelper.safely_drop_db_index(@index_name)
  end

  @impl HeavyDbIndexOperation
  def update_cache do
    BackgroundMigrations.set_heavy_indexes_drop_logs_block_number_asc_index_asc_index_finished(true)
  end
end
