# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Migrator.HeavyDbIndexOperation.RemoveLogsObsoleteColumns do
  @moduledoc """
  Removes `data`, `block_hash`, `transaction_hash`, `address_hash` and `first_topic` columns from `logs`.

  They are superseded by `compressed_data`, `block_number`, `transaction_index`, `address_id` and `first_topic_id`
  columns respectively.
  """

  use Explorer.Migrator.HeavyDbIndexOperation

  require Logger

  alias Explorer.Migrator.{FillLogsCompressedData, FillLogsOptimizedFields, HeavyDbIndexOperation, MigrationStatus}

  alias Explorer.Migrator.HeavyDbIndexOperation.{
    DropLogsAddressHashFirstTopicSecondTopicBlockNumberIndex,
    DropLogsDepositsWithdrawalsIndex,
    UpdateLogsPrimaryKey
  }

  alias Explorer.Repo

  @table_name :logs
  @index_name "logs_remove_obsolete_columns"
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
      FillLogsOptimizedFields.migration_name(),
      FillLogsCompressedData.migration_name(),
      UpdateLogsPrimaryKey.migration_name(),
      DropLogsAddressHashFirstTopicSecondTopicBlockNumberIndex.migration_name(),
      DropLogsDepositsWithdrawalsIndex.migration_name()
    ]

  @impl HeavyDbIndexOperation
  # sobelow_skip ["SQL"]
  def db_index_operation do
    Logger.info("Migration RemoveLogsObsoleteColumns started")

    with {:ok, _} <- drop_blocks_foreign_key(),
         {:ok, _} <- drop_transactions_foreign_key(),
         {:ok, _} <- Repo.query(drop_columns_query_string(), [], timeout: :infinity) do
      Logger.info("Migration RemoveLogsObsoleteColumns finished")
      :ok
    else
      {:error, error} ->
        Logger.error("Migration RemoveLogsObsoleteColumns failed: #{inspect(error)}")

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
           WHERE table_name = '#{@table_name}' AND column_name IN ('data', 'block_hash', 'transaction_hash', 'address_hash', 'first_topic');
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

  # The foreign keys are dropped before the columns, with the tables locked explicitly in the same order as in
  # `Explorer.Migrator.HeavyDbIndexOperation.RemoveInternalTransactionsBlockHashTransactionHashBlockIndexError`,
  # to prevent deadlocks with the concurrent imports.
  # sobelow_skip ["SQL"]
  defp drop_blocks_foreign_key do
    if foreign_key_exists?("logs_block_hash_fkey") do
      do_drop_blocks_foreign_key()
    else
      {:ok, :dropped}
    end
  end

  # sobelow_skip ["SQL"]
  defp do_drop_blocks_foreign_key do
    Repo.transaction(
      fn ->
        with {:ok, _} <- Repo.query(lock_blocks_query_string(), [], timeout: :infinity),
             {:ok, _} <- Repo.query(drop_blocks_foreign_key_query_string(), [], timeout: :infinity) do
          Logger.info("Migration RemoveLogsObsoleteColumns finished blocks")
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
    if foreign_key_exists?("logs_transaction_hash_fkey") do
      do_drop_transactions_foreign_key()
    else
      {:ok, :dropped}
    end
  end

  # sobelow_skip ["SQL"]
  defp do_drop_transactions_foreign_key do
    Repo.transaction(
      fn ->
        with {:ok, _} <- Repo.query(lock_logs_query_string(), [], timeout: :infinity),
             {:ok, _} <- Repo.query(lock_transactions_query_string(), [], timeout: :infinity),
             {:ok, _} <- Repo.query(drop_transactions_foreign_key_query_string(), [], timeout: :infinity) do
          Logger.info("Migration RemoveLogsObsoleteColumns finished transactions")
          :ok
        else
          {:error, error} -> Repo.rollback(error)
        end
      end,
      timeout: :infinity
    )
  end

  # sobelow_skip ["SQL"]
  defp foreign_key_exists?(foreign_key_name) do
    {:ok, %Postgrex.Result{rows: [[exists?]]}} =
      Repo.query("""
      SELECT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = '#{foreign_key_name}'
      );
      """)

    exists?
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

  defp lock_logs_query_string do
    """
    LOCK TABLE #{@table_name} IN ACCESS EXCLUSIVE MODE;
    """
  end

  defp drop_blocks_foreign_key_query_string do
    """
    ALTER TABLE #{@table_name}
    DROP CONSTRAINT IF EXISTS logs_block_hash_fkey;
    """
  end

  defp drop_transactions_foreign_key_query_string do
    """
    ALTER TABLE #{@table_name}
    DROP CONSTRAINT IF EXISTS logs_transaction_hash_fkey;
    """
  end

  defp drop_columns_query_string do
    """
    ALTER TABLE #{@table_name}
    DROP COLUMN IF EXISTS data,
    DROP COLUMN IF EXISTS block_hash,
    DROP COLUMN IF EXISTS transaction_hash,
    DROP COLUMN IF EXISTS address_hash,
    DROP COLUMN IF EXISTS first_topic;
    """
  end
end
