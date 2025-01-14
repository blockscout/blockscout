defmodule Explorer.Chain.Cache.BackgroundMigrations do
  @moduledoc """
    Caches the completion status of various background database migrations in the Blockscout system.

    This module leverages the MapCache behavior to maintain an in-memory cache of whether specific
    database migrations have completed. It tracks the status of several critical migrations:

    * Transactions denormalization
    * Address token balance token type migrations (both current and historical)
    * Token transfer token type migrations
    * Sanitization of duplicated log index logs
    * Arbitrum DA records normalization

    Each migration status is cached to avoid frequent database checks, with a fallback mechanism
    that asynchronously updates the cache when a status is not found. The default status for
    any uncached migration is `false`, indicating the migration is not complete.

    The cache is particularly useful during the application startup and for performance-critical
    operations that need to quickly check if certain data migrations have been completed.
  """

  require Logger

  use Explorer.Chain.MapCache,
    name: :background_migrations_status,
    key: :transactions_denormalization_finished,
    key: :tb_token_type_finished,
    key: :ctb_token_type_finished,
    key: :tt_denormalization_finished,
    key: :sanitize_duplicated_log_index_logs_finished,
    key: :backfill_multichain_search_db_finished,
    key: :heavy_indexes_add_logs_block_hash_index_finished,
    key: :heavy_indexes_drop_logs_block_number_asc_index_asc_index_finished,
    key: :heavy_indexes_drop_token_transfers_block_number_asc_log_index_asc_index_finished,
    key: :heavy_indexes_drop_token_transfers_from_address_hash_transaction_hash_index_finished,
    key: :heavy_indexes_drop_token_transfers_to_address_hash_transaction_hash_index_finished,
    key: :heavy_indexes_drop_token_transfers_token_contract_address_hash_transaction_hash_index_finished,
    key: :heavy_indexes_drop_token_transfers_block_number_index_finished,
    key: :arbitrum_da_records_normalization_finished

  @dialyzer :no_match

  alias Explorer.Migrator.{
    AddressCurrentTokenBalanceTokenType,
    AddressTokenBalanceTokenType,
    ArbitrumDaRecordsNormalization,
    BackfillMultichainSearchDB,
    SanitizeDuplicatedLogIndexLogs,
    TokenTransferTokenType,
    TransactionsDenormalization
  }

  alias Explorer.Migrator.HeavyDbIndexOperation.{
    AddLogsBlockHashIndex,
    DropLogsBlockNumberAscIndexAscIndex,
    DropTokenTransfersBlockNumberAscLogIndexAscIndex,
    DropTokenTransfersBlockNumberIndex,
    DropTokenTransfersFromAddressHashTransactionHashIndex,
    DropTokenTransfersToAddressHashTransactionHashIndex,
    DropTokenTransfersTokenContractAddressHashTransactionHashIndex
  }

  defp handle_fallback(:transactions_denormalization_finished) do
    Task.start_link(fn ->
      set_transactions_denormalization_finished(TransactionsDenormalization.migration_finished?())
    end)

    {:return, false}
  end

  defp handle_fallback(:tb_token_type_finished) do
    Task.start_link(fn ->
      set_tb_token_type_finished(AddressTokenBalanceTokenType.migration_finished?())
    end)

    {:return, false}
  end

  defp handle_fallback(:ctb_token_type_finished) do
    Task.start_link(fn ->
      set_ctb_token_type_finished(AddressCurrentTokenBalanceTokenType.migration_finished?())
    end)

    {:return, false}
  end

  defp handle_fallback(:tt_denormalization_finished) do
    Task.start_link(fn ->
      set_tt_denormalization_finished(TokenTransferTokenType.migration_finished?())
    end)

    {:return, false}
  end

  defp handle_fallback(:sanitize_duplicated_log_index_logs_finished) do
    Task.start_link(fn ->
      set_sanitize_duplicated_log_index_logs_finished(SanitizeDuplicatedLogIndexLogs.migration_finished?())
    end)

    {:return, false}
  end

  defp handle_fallback(:backfill_multichain_search_db_finished) do
    Task.start_link(fn ->
      set_backfill_multichain_search_db_finished(BackfillMultichainSearchDB.migration_finished?())
    end)

    {:return, false}
  end

  defp handle_fallback(:heavy_indexes_add_logs_block_hash_index_finished) do
    Task.start_link(fn ->
      set_heavy_indexes_add_logs_block_hash_index_finished(AddLogsBlockHashIndex.migration_finished?())
    end)

    {:return, false}
  end

  defp handle_fallback(:heavy_indexes_drop_logs_block_number_asc_index_asc_index_finished) do
    Task.start_link(fn ->
      set_heavy_indexes_drop_logs_block_number_asc_index_asc_index_finished(
        DropLogsBlockNumberAscIndexAscIndex.migration_finished?()
      )
    end)

    {:return, false}
  end

  defp handle_fallback(:heavy_indexes_drop_token_transfers_block_number_asc_log_index_asc_index_finished) do
    Task.start_link(fn ->
      set_heavy_indexes_drop_token_transfers_block_number_asc_log_index_asc_index_finished(
        DropTokenTransfersBlockNumberAscLogIndexAscIndex.migration_finished?()
      )
    end)

    {:return, false}
  end

  defp handle_fallback(:heavy_indexes_drop_token_transfers_from_address_hash_transaction_hash_index_finished) do
    Task.start_link(fn ->
      set_heavy_indexes_drop_token_transfers_from_address_hash_transaction_hash_index_finished(
        DropTokenTransfersFromAddressHashTransactionHashIndex.migration_finished?()
      )
    end)

    {:return, false}
  end

  defp handle_fallback(:heavy_indexes_drop_token_transfers_to_address_hash_transaction_hash_index_finished) do
    Task.start_link(fn ->
      set_heavy_indexes_drop_token_transfers_to_address_hash_transaction_hash_index_finished(
        DropTokenTransfersToAddressHashTransactionHashIndex.migration_finished?()
      )
    end)

    {:return, false}
  end

  defp handle_fallback(:heavy_indexes_drop_token_transfers_token_contract_address_hash_transaction_hash_index_finished) do
    Task.start_link(fn ->
      set_heavy_indexes_drop_token_transfers_token_contract_address_hash_transaction_hash_index_finished(
        DropTokenTransfersTokenContractAddressHashTransactionHashIndex.migration_finished?()
      )
    end)

    {:return, false}
  end

  defp handle_fallback(:heavy_indexes_drop_token_transfers_block_number_index_finished) do
    Task.start_link(fn ->
      set_heavy_indexes_drop_token_transfers_block_number_index_finished(
        DropTokenTransfersBlockNumberIndex.migration_finished?()
      )
    end)

    {:return, false}
  end

  defp handle_fallback(:arbitrum_da_records_normalization_finished) do
    Task.start_link(fn ->
      set_arbitrum_da_records_normalization_finished(ArbitrumDaRecordsNormalization.migration_finished?())
    end)

    {:return, false}
  end
end
