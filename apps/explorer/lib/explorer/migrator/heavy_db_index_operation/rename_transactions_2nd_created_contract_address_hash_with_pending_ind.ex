defmodule Explorer.Migrator.HeavyDbIndexOperation.RenameTransactions2ndCreatedContractAddressHashWithPendingInd do
  @moduledoc """
  Renames index "transactions_2nd_created_contract_address_hash_with_pending_ind" to "transactions_created_contract_address_hash_with_pending_index_a".
  """

  use Explorer.Migrator.HeavyDbIndexOperation

  require Logger

  alias Explorer.Chain.Cache.BackgroundMigrations
  alias Explorer.Migrator.{HeavyDbIndexOperation, MigrationStatus}
  alias Explorer.Migrator.HeavyDbIndexOperation.Helper, as: HeavyDbIndexOperationHelper
  alias Explorer.Migrator.HeavyDbIndexOperation.DropTransactionsCreatedContractAddressHashWithPendingIndexA
  alias Explorer.Repo

  @table_name :transactions
  @old_index_name "transactions_2nd_created_contract_address_hash_with_pending_ind"
  @new_index_name "transactions_created_contract_address_hash_with_pending_index_a"
  @operation_type :create

  @impl HeavyDbIndexOperation
  def table_name, do: @table_name

  @impl HeavyDbIndexOperation
  def operation_type, do: @operation_type

  @impl HeavyDbIndexOperation
  def index_name, do: @new_index_name

  @impl HeavyDbIndexOperation
  def dependent_from_migrations do
    [DropTransactionsCreatedContractAddressHashWithPendingIndexA.migration_name()]
  end

  @impl HeavyDbIndexOperation
  # sobelow_skip ["SQL"]
  def db_index_operation do
    case Repo.query(rename_index_query_string(), [], timeout: :infinity) do
      {:ok, _} ->
        update_cache()
        :ok

      {:error, error} ->
        Logger.error("Failed to rename index from #{@old_index_name} to #{@new_index_name}: #{inspect(error)}")
        :error
    end
  end

  @impl HeavyDbIndexOperation
  def check_db_index_operation_progress do
    HeavyDbIndexOperationHelper.check_db_index_operation_progress(@new_index_name, rename_index_query_string())
  end

  @impl HeavyDbIndexOperation
  def db_index_operation_status do
    old_index_status = HeavyDbIndexOperationHelper.db_index_exists_and_valid?(@old_index_name)
    new_index_status = HeavyDbIndexOperationHelper.db_index_exists_and_valid?(@new_index_name)

    cond do
      # Rename completed: old index doesn't exist, new index exists and is valid
      old_index_status == %{exists?: false, valid?: nil} and new_index_status == %{exists?: true, valid?: true} ->
        :completed

      # Rename not started: old index exists, new index doesn't exist
      old_index_status == %{exists?: true, valid?: true} and new_index_status == %{exists?: false, valid?: nil} ->
        :not_initialized

      # Unknown state
      true ->
        :unknown
    end
  end

  @impl HeavyDbIndexOperation
  def restart_db_index_operation do
    # To restart, we need to rename back to the old name
    case Repo.query(reverse_rename_index_query_string(), [], timeout: :infinity) do
      {:ok, _} ->
        :ok

      {:error, error} ->
        Logger.error("Failed to reverse rename index from #{@new_index_name} to #{@old_index_name}: #{inspect(error)}")
        :error
    end
  end

  @impl HeavyDbIndexOperation
  def running_other_heavy_migration_exists?(migration_name) do
    MigrationStatus.running_other_heavy_migration_for_table_exists?(@table_name, migration_name)
  end

  @impl HeavyDbIndexOperation
  def update_cache do
    BackgroundMigrations.set_heavy_indexes_rename_transactions_2nd_created_contract_address_hash_with_pending_ind_finished(
      true
    )
  end

  defp rename_index_query_string do
    "ALTER INDEX #{@old_index_name} RENAME TO #{@new_index_name};"
  end

  defp reverse_rename_index_query_string do
    "ALTER INDEX #{@new_index_name} RENAME TO #{@old_index_name};"
  end
end
