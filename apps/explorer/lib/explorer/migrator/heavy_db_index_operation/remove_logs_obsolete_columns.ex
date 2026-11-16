# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Migrator.HeavyDbIndexOperation.RemoveLogsObsoleteColumns do
  @moduledoc """
  Removes `data`, `block_hash`, `transaction_hash`, `address_hash` and `first_topic` columns from `logs`.

  They are superseded by `compressed_data`, `block_number`, `transaction_index`, `address_id` and `first_topic_id`
  columns respectively.
  """

  use Explorer.Migrator.HeavyDbIndexOperation

  require Logger

  alias Explorer.Migrator.{
    DeleteNonConsensusLogs,
    FillLogsCompressedData,
    FillLogsOptimizedFields,
    HeavyDbIndexOperation
  }

  alias Explorer.Migrator.HeavyDbIndexOperation.{
    CreateLogsAddressHashBlockNumberDescIndexDescIndex,
    CreateLogsAddressHashFirstTopicBlockNumberIndexIndex,
    CreateLogsAddressHashFirstTopicSecondTopicBlockNumberIndex,
    CreateLogsBlockHashIndex,
    CreateLogsDepositsWithdrawalsIndex,
    DropLogsAddressHashFirstTopicSecondTopicBlockNumberIndex,
    DropLogsDepositsWithdrawalsIndex,
    UpdateLogsPrimaryKey
  }

  alias Explorer.Repo

  @table_name :logs
  @index_name "logs_remove_obsolete_columns"
  @operation_type :create

  # The lock wait of each step, in milliseconds. While an `ACCESS EXCLUSIVE` lock request waits for
  # a long-running query, every other query on the table queues behind it, so the wait is bounded:
  # on a timeout the step's transaction is rolled back and the operation is retried later.
  @lock_timeout 5_000

  # Besides the migrations filling the new columns, the operation waits for all the migrations which
  # read the removed columns or create indexes on them: otherwise such a migration started after the
  # removal would fail, and its "started" status would block the other heavy operations on `logs`.
  @impl HeavyDbIndexOperation
  def dependent_from_migrations,
    do: [
      FillLogsOptimizedFields.migration_name(),
      FillLogsCompressedData.migration_name(),
      UpdateLogsPrimaryKey.migration_name(),
      DeleteNonConsensusLogs.migration_name(),
      CreateLogsBlockHashIndex.migration_name(),
      CreateLogsAddressHashBlockNumberDescIndexDescIndex.migration_name(),
      CreateLogsAddressHashFirstTopicBlockNumberIndexIndex.migration_name(),
      CreateLogsAddressHashFirstTopicSecondTopicBlockNumberIndex.migration_name(),
      CreateLogsDepositsWithdrawalsIndex.migration_name(),
      DropLogsAddressHashFirstTopicSecondTopicBlockNumberIndex.migration_name(),
      DropLogsDepositsWithdrawalsIndex.migration_name()
    ]

  @impl HeavyDbIndexOperation
  # sobelow_skip ["SQL"]
  def db_index_operation do
    Logger.info("Migration RemoveLogsObsoleteColumns started")

    with {:ok, _} <- drop_blocks_foreign_key(),
         {:ok, _} <- drop_transactions_foreign_key(),
         {:ok, _} <- drop_columns() do
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
        with {:ok, _} <- Repo.query(set_lock_timeout_query_string(), [], timeout: :infinity),
             {:ok, _} <- Repo.query(lock_blocks_query_string(), [], timeout: :infinity),
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
        with {:ok, _} <- Repo.query(set_lock_timeout_query_string(), [], timeout: :infinity),
             {:ok, _} <- Repo.query(lock_logs_query_string(), [], timeout: :infinity),
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
  defp drop_columns do
    Repo.transaction(
      fn ->
        with {:ok, _} <- Repo.query(set_lock_timeout_query_string(), [], timeout: :infinity),
             {:ok, _} <- Repo.query(drop_columns_query_string(), [], timeout: :infinity) do
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

  defp set_lock_timeout_query_string do
    """
    SET LOCAL lock_timeout = #{@lock_timeout};
    """
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
