defmodule Explorer.Migrator.HeavyDbIndexOperation.CreateSmartContractAdditionalSourcesUniqueIndex do
  @moduledoc """
  Creates a unique index on the smart_contract_additional_sources table.
  """

  use Explorer.Migrator.HeavyDbIndexOperation

  require Logger

  alias Explorer.Migrator.{
    HeavyDbIndexOperation,
    MigrationStatus,
    SanitizeDuplicateSmartContractAdditionalSources
  }

  alias Explorer.Migrator.HeavyDbIndexOperation.Helper, as: HeavyDbIndexOperationHelper

  @table_name :smart_contracts_additional_sources
  @index_name "smart_contracts_additional_sources_file_name_address_hash_index"
  @operation_type :create

  @impl HeavyDbIndexOperation
  def table_name, do: @table_name

  @impl HeavyDbIndexOperation
  def operation_type, do: @operation_type

  @impl HeavyDbIndexOperation
  def index_name, do: @index_name

  @impl HeavyDbIndexOperation
  def dependent_from_migrations,
    do: [SanitizeDuplicateSmartContractAdditionalSources.migration_name()]

  @query_string """
  CREATE UNIQUE INDEX #{HeavyDbIndexOperationHelper.add_concurrently_flag?()} IF NOT EXISTS "#{@index_name}"
   ON #{@table_name} (address_hash, file_name);
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
