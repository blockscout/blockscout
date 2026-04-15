defmodule Explorer.Migrator.HeavyDbIndexOperation.RemoveInternalTransactionsBlockHashTransactionHashBlockIndexError do
  @moduledoc """
  Removes `block_hash`, `transaction_hash`, `block_index` and `error` columns from `internal_transactions`
  """

  use Explorer.Migrator.HeavyDbIndexOperation

  require Logger

  alias Explorer.Migrator.{HeavyDbIndexOperation, MigrationStatus}

  alias Explorer.Migrator.HeavyDbIndexOperation.{
    CreateInternalTransactionsBlockNumberCreatedContractAddressIdPartialIndex,
    CreateInternalTransactionsCreatedContractAddressIdIndex,
    CreateInternalTransactionsFromAddressIdPartialIndex,
    CreateInternalTransactionsToAddressIdPartialIndex,
    UpdateInternalTransactionsPrimaryKey
  }

  alias Explorer.Repo

  @table_name :internal_transactions
  @index_name "internal_transactions_remove_block_hash_transaction_hash_block_index_error"
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
      UpdateInternalTransactionsPrimaryKey.migration_name(),
      CreateInternalTransactionsCreatedContractAddressIdIndex.migration_name(),
      CreateInternalTransactionsBlockNumberCreatedContractAddressIdPartialIndex.migration_name(),
      CreateInternalTransactionsFromAddressIdPartialIndex.migration_name(),
      CreateInternalTransactionsToAddressIdPartialIndex.migration_name()
    ]

  @impl HeavyDbIndexOperation
  # sobelow_skip ["SQL"]
  def db_index_operation do
    Logger.info("Migration RemoveInternalTransactionsBlockHashTransactionHashBlockIndexError started")

    with {:ok, _} <- drop_blocks_foreign_key(),
         {:ok, _} <- drop_transactions_foreign_key(),
         {:ok, _} <- Repo.query(drop_columns_query_string(), [], timeout: :infinity) do
      Logger.info("Migration RemoveInternalTransactionsBlockHashTransactionHashBlockIndexError finished")
      :ok
    else
      {:error, error} ->
        Logger.error(
          "Migration RemoveInternalTransactionsBlockHashTransactionHashBlockIndexError failed: #{inspect(error)}"
        )

        :error
    end
  end

  @impl HeavyDbIndexOperation
  def check_db_index_operation_progress do
    HeavyDbIndexOperationHelper.check_db_index_operation_progress(@index_name, drop_columns_query_string())
  end

  @impl HeavyDbIndexOperation
  # credo:disable-for-next-line /Complexity/
  def db_index_operation_status do
    completed? =
      case Repo.query("""
           SELECT COUNT(*) = 0
           FROM information_schema.columns
           WHERE table_name = '#{@table_name}' AND column_name IN ('block_hash', 'transaction_hash', 'block_index', 'error');
           """) do
        {:ok, %Postgrex.Result{rows: [[completed]]}} -> completed
        _ -> nil
      end

    started? =
      case check_db_index_operation_progress() do
        :in_progress -> true
        :finished_or_not_started -> false
        _ -> nil
      end

    cond do
      completed? == true -> :completed
      started? == true -> :not_completed
      is_nil(completed?) or is_nil(started?) -> :unknown
      true -> :not_initialized
    end
  end

  @impl HeavyDbIndexOperation
  # sobelow_skip ["SQL"]
  def restart_db_index_operation, do: db_index_operation()

  @impl HeavyDbIndexOperation
  def running_other_heavy_migration_exists?(migration_name) do
    MigrationStatus.running_other_heavy_migration_for_table_exists?(@table_name, migration_name)
  end

  @impl HeavyDbIndexOperation
  def update_cache, do: :ok

  # sobelow_skip ["SQL"]
  defp drop_blocks_foreign_key do
    Repo.transaction(
      fn ->
        with {:ok, _} <- Repo.query(lock_blocks_query_string(), [], timeout: :infinity),
             {:ok, _} <- Repo.query(drop_blocks_foreign_key_query_string(), [], timeout: :infinity) do
          Logger.info("Migration RemoveInternalTransactionsBlockHashTransactionHashBlockIndexError finished blocks")
          :ok
        else
          {:error, error} -> Repo.rollback(error)
        end
      end,
      timeout: :infinity
    )
  end

  # sobelow_skip ["SQL"]
  defp drop_transactions_foreign_key do
    Repo.transaction(
      fn ->
        with {:ok, _} <- Repo.query(lock_transactions_query_string(), [], timeout: :infinity),
             {:ok, _} <- Repo.query(drop_transactions_foreign_key_query_string(), [], timeout: :infinity) do
          Logger.info(
            "Migration RemoveInternalTransactionsBlockHashTransactionHashBlockIndexError finished transactions"
          )

          :ok
        else
          {:error, error} -> Repo.rollback(error)
        end
      end,
      timeout: :infinity
    )
  end

  defp lock_blocks_query_string do
    """
    LOCK TABLE blocks IN ACCESS EXCLUSIVE MODE;
    """
  end

  defp lock_transactions_query_string do
    """
    LOCK TABLE transactions IN ACCESS EXCLUSIVE MODE;
    """
  end

  defp drop_blocks_foreign_key_query_string do
    """
    ALTER TABLE #{@table_name}
    DROP CONSTRAINT IF EXISTS internal_transactions_block_hash_fkey;
    """
  end

  defp drop_transactions_foreign_key_query_string do
    """
    ALTER TABLE #{@table_name}
    DROP CONSTRAINT IF EXISTS internal_transactions_transaction_hash_fkey;
    """
  end

  defp drop_columns_query_string do
    """
    ALTER TABLE #{@table_name}
    DROP COLUMN IF EXISTS block_hash,
    DROP COLUMN IF EXISTS transaction_hash,
    DROP COLUMN IF EXISTS block_index,
    DROP COLUMN IF EXISTS error;
    """
  end
end
