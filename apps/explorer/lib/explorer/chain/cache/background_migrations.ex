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
    key: :heavy_indexes_create_logs_block_hash_index_finished,
    key: :heavy_indexes_drop_logs_block_number_asc_index_asc_index_finished,
    key: :heavy_indexes_create_logs_address_hash_block_number_desc_index_desc_index_finished,
    key: :heavy_indexes_drop_logs_address_hash_index_finished,
    key: :heavy_indexes_drop_logs_address_hash_transaction_hash_index_finished,
    key: :heavy_indexes_drop_logs_index_index_finished,
    key: :heavy_indexes_create_logs_address_hash_first_topic_block_number_index_index_finished,
    key: :heavy_indexes_drop_token_transfers_block_number_asc_log_index_asc_index_finished,
    key: :heavy_indexes_drop_token_transfers_from_address_hash_transaction_hash_index_finished,
    key: :heavy_indexes_drop_token_transfers_to_address_hash_transaction_hash_index_finished,
    key: :heavy_indexes_drop_token_transfers_token_contract_address_hash_transaction_hash_index_finished,
    key: :heavy_indexes_drop_token_transfers_block_number_index_finished,
    key: :heavy_indexes_drop_internal_transactions_from_address_hash_index_finished,
    key: :heavy_indexes_create_internal_transactions_block_number_desc_transaction_index_desc_index_desc_index_finished,
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
    CreateInternalTransactionsBlockNumberDescTransactionIndexDescIndexDescIndex,
    CreateLogsAddressHashBlockNumberDescIndexDescIndex,
    CreateLogsAddressHashFirstTopicBlockNumberIndexIndex,
    CreateLogsBlockHashIndex,
    DropInternalTransactionsFromAddressHashIndex,
    DropLogsAddressHashIndex,
    DropLogsAddressHashTransactionHashIndex,
    DropLogsBlockNumberAscIndexAscIndex,
    DropLogsIndexIndex,
    DropTokenTransfersBlockNumberAscLogIndexAscIndex,
    DropTokenTransfersBlockNumberIndex,
    DropTokenTransfersFromAddressHashTransactionHashIndex,
    DropTokenTransfersToAddressHashTransactionHashIndex,
    DropTokenTransfersTokenContractAddressHashTransactionHashIndex
  }

  defp handle_fallback(:transactions_denormalization_finished) do
    start_migration_status_task(
      TransactionsDenormalization,
      &set_transactions_denormalization_finished/1
    )
  end

  defp handle_fallback(:tb_token_type_finished) do
    start_migration_status_task(
      AddressTokenBalanceTokenType,
      &set_tb_token_type_finished/1
    )
  end

  defp handle_fallback(:ctb_token_type_finished) do
    start_migration_status_task(
      AddressCurrentTokenBalanceTokenType,
      &set_ctb_token_type_finished/1
    )
  end

  defp handle_fallback(:tt_denormalization_finished) do
    start_migration_status_task(
      TokenTransferTokenType,
      &set_tt_denormalization_finished/1
    )
  end

  defp handle_fallback(:sanitize_duplicated_log_index_logs_finished) do
    start_migration_status_task(
      SanitizeDuplicatedLogIndexLogs,
      &set_sanitize_duplicated_log_index_logs_finished/1
    )
  end

  defp handle_fallback(:backfill_multichain_search_db_finished) do
    start_migration_status_task(
      BackfillMultichainSearchDB,
      &set_backfill_multichain_search_db_finished/1
    )
  end

  defp handle_fallback(:heavy_indexes_create_logs_block_hash_index_finished) do
    start_migration_status_task(
      CreateLogsBlockHashIndex,
      &set_heavy_indexes_create_logs_block_hash_index_finished/1
    )
  end

  defp handle_fallback(:heavy_indexes_drop_logs_block_number_asc_index_asc_index_finished) do
    start_migration_status_task(
      DropLogsBlockNumberAscIndexAscIndex,
      &set_heavy_indexes_drop_logs_block_number_asc_index_asc_index_finished/1
    )
  end

  defp handle_fallback(:heavy_indexes_create_logs_address_hash_block_number_desc_index_desc_index_finished) do
    start_migration_status_task(
      CreateLogsAddressHashBlockNumberDescIndexDescIndex,
      &set_heavy_indexes_create_logs_address_hash_block_number_desc_index_desc_index_finished/1
    )
  end

  defp handle_fallback(:heavy_indexes_drop_logs_address_hash_index_finished) do
    start_migration_status_task(
      DropLogsAddressHashIndex,
      &set_heavy_indexes_drop_logs_address_hash_index_finished/1
    )
  end

  defp handle_fallback(:heavy_indexes_drop_logs_address_hash_transaction_hash_index_finished) do
    start_migration_status_task(
      DropLogsAddressHashTransactionHashIndex,
      &set_heavy_indexes_drop_logs_address_hash_transaction_hash_index_finished/1
    )
  end

  defp handle_fallback(:heavy_indexes_drop_logs_index_index_finished) do
    start_migration_status_task(
      DropLogsIndexIndex,
      &set_heavy_indexes_drop_logs_index_index_finished/1
    )
  end

  defp handle_fallback(:heavy_indexes_create_logs_address_hash_first_topic_block_number_index_index_finished) do
    start_migration_status_task(
      CreateLogsAddressHashFirstTopicBlockNumberIndexIndex,
      &set_heavy_indexes_create_logs_address_hash_first_topic_block_number_index_index_finished/1
    )
  end

  defp handle_fallback(:heavy_indexes_drop_token_transfers_block_number_asc_log_index_asc_index_finished) do
    start_migration_status_task(
      DropTokenTransfersBlockNumberAscLogIndexAscIndex,
      &set_heavy_indexes_drop_token_transfers_block_number_asc_log_index_asc_index_finished/1
    )
  end

  defp handle_fallback(:heavy_indexes_drop_token_transfers_from_address_hash_transaction_hash_index_finished) do
    start_migration_status_task(
      DropTokenTransfersFromAddressHashTransactionHashIndex,
      &set_heavy_indexes_drop_token_transfers_from_address_hash_transaction_hash_index_finished/1
    )
  end

  defp handle_fallback(:heavy_indexes_drop_token_transfers_to_address_hash_transaction_hash_index_finished) do
    start_migration_status_task(
      DropTokenTransfersToAddressHashTransactionHashIndex,
      &set_heavy_indexes_drop_token_transfers_to_address_hash_transaction_hash_index_finished/1
    )
  end

  defp handle_fallback(:heavy_indexes_drop_token_transfers_token_contract_address_hash_transaction_hash_index_finished) do
    start_migration_status_task(
      DropTokenTransfersTokenContractAddressHashTransactionHashIndex,
      &set_heavy_indexes_drop_token_transfers_token_contract_address_hash_transaction_hash_index_finished/1
    )
  end

  defp handle_fallback(:heavy_indexes_drop_token_transfers_block_number_index_finished) do
    start_migration_status_task(
      DropTokenTransfersBlockNumberIndex,
      &set_heavy_indexes_drop_token_transfers_block_number_index_finished/1
    )
  end

  defp handle_fallback(:heavy_indexes_drop_internal_transactions_from_address_hash_index_finished) do
    start_migration_status_task(
      DropInternalTransactionsFromAddressHashIndex,
      &set_heavy_indexes_drop_internal_transactions_from_address_hash_index_finished/1
    )
  end

  defp handle_fallback(
         :heavy_indexes_create_internal_transactions_block_number_desc_transaction_index_desc_index_desc_index_finished
       ) do
    start_migration_status_task(
      CreateInternalTransactionsBlockNumberDescTransactionIndexDescIndexDescIndex,
      &set_heavy_indexes_create_internal_transactions_block_number_desc_transaction_index_desc_index_desc_index_finished/1
    )
  end

  defp handle_fallback(:arbitrum_da_records_normalization_finished) do
    start_migration_status_task(
      ArbitrumDaRecordsNormalization,
      &set_arbitrum_da_records_normalization_finished/1
    )
  end

  defp start_migration_status_task(migration_module, status_setter) do
    Task.start_link(fn ->
      status_setter.(migration_module.migration_finished?())
    end)

    {:return, false}
  end
end
