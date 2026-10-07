# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Migrator.HeavyDbIndexOperation.RemoveArbitrumBatchL2BlocksConfirmationId do
  @moduledoc """
  Removes the column `confirmation_id` from `arbitrum_batch_l2_blocks`.

  The confirmations of rollup blocks live in `arbitrum_rollup_block_confirmations`.
  `DROP COLUMN` also removes the index on `confirmation_id` and the foreign key to
  `arbitrum_lifecycle_l1_transactions`. It changes only the catalog of PostgreSQL
  and takes a short `ACCESS EXCLUSIVE` lock.

  The framework has no operation type for a column. Thus the migration uses the
  type `:create` with an index name that names no real index, and it gets its
  status from `information_schema.columns`. The migration waits for
  `DropArbitrumBatchL2BlocksUnconfirmedBlocksIndex`, so that the large partial
  index goes away without a lock of the table.
  """

  use Explorer.Migrator.HeavyDbIndexOperation

  require Logger

  alias Explorer.Migrator.{HeavyDbIndexOperation, MigrationStatus}
  alias Explorer.Migrator.HeavyDbIndexOperation.DropArbitrumBatchL2BlocksUnconfirmedBlocksIndex
  alias Explorer.Repo

  @table_name :arbitrum_batch_l2_blocks
  @column_name "confirmation_id"
  @index_name "arbitrum_batch_l2_blocks_remove_confirmation_id"
  @operation_type :create

  @impl HeavyDbIndexOperation
  def table_name, do: @table_name

  @impl HeavyDbIndexOperation
  def operation_type, do: @operation_type

  @impl HeavyDbIndexOperation
  def index_name, do: @index_name

  @impl HeavyDbIndexOperation
  def dependent_from_migrations, do: [DropArbitrumBatchL2BlocksUnconfirmedBlocksIndex.migration_name()]

  @impl HeavyDbIndexOperation
  # sobelow_skip ["SQL"]
  def db_index_operation do
    Logger.info("Migration RemoveArbitrumBatchL2BlocksConfirmationId started")

    case Repo.query(drop_column_query_string(), [], timeout: :infinity) do
      {:ok, _} ->
        Logger.info("Migration RemoveArbitrumBatchL2BlocksConfirmationId finished")
        :ok

      {:error, error} ->
        Logger.error("Migration RemoveArbitrumBatchL2BlocksConfirmationId failed: #{inspect(error)}")

        :error
    end
  end

  @impl HeavyDbIndexOperation
  def check_db_index_operation_progress do
    HeavyDbIndexOperationHelper.check_db_index_operation_progress(@index_name, drop_column_query_string())
  end

  @impl HeavyDbIndexOperation
  # credo:disable-for-next-line /Complexity/
  def db_index_operation_status do
    completed? =
      case Repo.query("""
           SELECT COUNT(*) = 0
           FROM information_schema.columns
           WHERE table_name = '#{@table_name}' AND column_name = '#{@column_name}';
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
  def restart_db_index_operation, do: db_index_operation()

  @impl HeavyDbIndexOperation
  def running_other_heavy_migration_exists?(migration_name) do
    MigrationStatus.running_other_heavy_migration_for_table_exists?(@table_name, migration_name)
  end

  @impl HeavyDbIndexOperation
  def update_cache, do: :ok

  defp drop_column_query_string do
    """
    ALTER TABLE #{@table_name}
    DROP COLUMN IF EXISTS #{@column_name};
    """
  end
end
