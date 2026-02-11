defmodule Explorer.Chain.Cache.BackgroundMigrations do
  @moduledoc """
  Caches the completion status of various background database operations in the Blockscout system.

  This module leverages the MapCache behavior to maintain an in-memory cache of whether specific
  database operations have completed. These operations include:
  * Database table migrations
  * Heavy index operations (creation and dropping)
  * Data sanitization tasks
  * Schema normalization processes

  Each operation status is cached to avoid frequent database checks, with a fallback mechanism
  that asynchronously updates the cache when a status is not found. The default status for
  any uncached operation is `false`, indicating the operation is not complete.

  The cache is particularly useful during the application startup and for performance-critical
  operations that need to quickly check if certain database operations have been completed.
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
    key: :arbitrum_da_records_normalization_finished,
    key: :sanitize_verified_addresses_finished,
    key: :smart_contract_language_finished,
    key: :backfill_call_type_enum_finished,
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
    key: :heavy_indexes_create_addresses_verified_index_finished,
    key: :heavy_indexes_create_addresses_verified_hash_index_finished,
    key: :heavy_indexes_create_addresses_verified_transactions_count_desc_hash_index_finished,
    key: :heavy_indexes_create_addresses_verified_fetched_coin_balance_desc_hash_index_finished,
    key: :heavy_indexes_create_smart_contracts_language_index_finished,
    key: :heavy_indexes_create_arbitrum_batch_l2_blocks_unconfirmed_blocks_index_finished,
    key: :heavy_indexes_drop_transactions_created_contract_address_hash_with_pending_index_finished,
    key: :heavy_indexes_drop_transactions_from_address_hash_with_pending_index_finished,
    key: :heavy_indexes_drop_transactions_to_address_hash_with_pending_index_finished,
    key: :heavy_indexes_create_logs_deposits_withdrawals_index_finished,
    key: :heavy_indexes_create_addresses_transactions_count_desc_partial_index_finished,
    key: :heavy_indexes_create_addresses_transactions_count_asc_coin_balance_desc_hash_partial_index_finished,
    key: :heavy_indexes_drop_token_instances_token_id_index_finished,
    key: :fill_internal_transaction_to_address_hash_with_created_contract_address_hash_finished,
    key: :heavy_indexes_drop_internal_transactions_created_contract_address_hash_partial_index_finished,
    key: :heavy_indexes_create_tokens_name_partial_fts_index_finished,
    key: :heavy_indexes_update_internal_transactions_primary_key_finished,
    key: :empty_internal_transactions_data_finished

  @dialyzer :no_match

  alias Explorer.Migrator.{
    AddressCurrentTokenBalanceTokenType,
    AddressTokenBalanceTokenType,
    ArbitrumDaRecordsNormalization,
    BackfillMultichainSearchDB,
    EmptyInternalTransactionsData,
    SanitizeDuplicatedLogIndexLogs,
    SmartContractLanguage,
    TokenTransferTokenType,
    TransactionsDenormalization
  }

  alias Explorer.Migrator.HeavyDbIndexOperation.{
    CreateAddressesTransactionsCountAscCoinBalanceDescHashPartialIndex,
    CreateAddressesTransactionsCountDescPartialIndex,
    CreateAddressesVerifiedFetchedCoinBalanceDescHashIndex,
    CreateAddressesVerifiedHashIndex,
    CreateAddressesVerifiedTransactionsCountDescHashIndex,
    CreateArbitrumBatchL2BlocksUnconfirmedBlocksIndex,
    CreateInternalTransactionsBlockNumberDescTransactionIndexDescIndexDescIndex,
    CreateLogsAddressHashBlockNumberDescIndexDescIndex,
    CreateLogsAddressHashFirstTopicBlockNumberIndexIndex,
    CreateLogsBlockHashIndex,
    CreateLogsDepositsWithdrawalsIndex,
    CreateSmartContractsLanguageIndex,
    CreateTokensNamePartialFtsIndex,
    DropInternalTransactionsCreatedContractAddressHashPartialIndex,
    DropInternalTransactionsFromAddressHashIndex,
    DropLogsAddressHashIndex,
    DropLogsAddressHashTransactionHashIndex,
    DropLogsBlockNumberAscIndexAscIndex,
    DropLogsIndexIndex,
    DropTokenInstancesTokenIdIndex,
    DropTokenTransfersBlockNumberAscLogIndexAscIndex,
    DropTokenTransfersBlockNumberIndex,
    DropTokenTransfersFromAddressHashTransactionHashIndex,
    DropTokenTransfersToAddressHashTransactionHashIndex,
    DropTokenTransfersTokenContractAddressHashTransactionHashIndex,
    DropTransactionsCreatedContractAddressHashWithPendingIndex,
    DropTransactionsFromAddressHashWithPendingIndex,
    DropTransactionsToAddressHashWithPendingIndex,
    UpdateInternalTransactionsPrimaryKey
  }

  defp handle_fallback(:transactions_denormalization_finished) do
    set_and_return_migration_status(
      TransactionsDenormalization,
      &set_transactions_denormalization_finished/1
    )
  end

  defp handle_fallback(:tb_token_type_finished) do
    set_and_return_migration_status(
      AddressTokenBalanceTokenType,
      &set_tb_token_type_finished/1
    )
  end

  defp handle_fallback(:ctb_token_type_finished) do
    set_and_return_migration_status(
      AddressCurrentTokenBalanceTokenType,
      &set_ctb_token_type_finished/1
    )
  end

  defp handle_fallback(:tt_denormalization_finished) do
    set_and_return_migration_status(
      TokenTransferTokenType,
      &set_tt_denormalization_finished/1
    )
  end

  defp handle_fallback(:sanitize_duplicated_log_index_logs_finished) do
    set_and_return_migration_status(
      SanitizeDuplicatedLogIndexLogs,
      &set_sanitize_duplicated_log_index_logs_finished/1
    )
  end

  defp handle_fallback(:backfill_multichain_search_db_finished) do
    set_and_return_migration_status(
      BackfillMultichainSearchDB,
      &set_backfill_multichain_search_db_finished/1
    )
  end

  defp handle_fallback(:heavy_indexes_create_logs_block_hash_index_finished) do
    set_and_return_migration_status(
      CreateLogsBlockHashIndex,
      &set_heavy_indexes_create_logs_block_hash_index_finished/1
    )
  end

  defp handle_fallback(:heavy_indexes_drop_logs_block_number_asc_index_asc_index_finished) do
    set_and_return_migration_status(
      DropLogsBlockNumberAscIndexAscIndex,
      &set_heavy_indexes_drop_logs_block_number_asc_index_asc_index_finished/1
    )
  end

  defp handle_fallback(:heavy_indexes_create_logs_address_hash_block_number_desc_index_desc_index_finished) do
    set_and_return_migration_status(
      CreateLogsAddressHashBlockNumberDescIndexDescIndex,
      &set_heavy_indexes_create_logs_address_hash_block_number_desc_index_desc_index_finished/1
    )
  end

  defp handle_fallback(:heavy_indexes_drop_logs_address_hash_index_finished) do
    set_and_return_migration_status(
      DropLogsAddressHashIndex,
      &set_heavy_indexes_drop_logs_address_hash_index_finished/1
    )
  end

  defp handle_fallback(:heavy_indexes_drop_logs_address_hash_transaction_hash_index_finished) do
    set_and_return_migration_status(
      DropLogsAddressHashTransactionHashIndex,
      &set_heavy_indexes_drop_logs_address_hash_transaction_hash_index_finished/1
    )
  end

  defp handle_fallback(:heavy_indexes_drop_logs_index_index_finished) do
    set_and_return_migration_status(
      DropLogsIndexIndex,
      &set_heavy_indexes_drop_logs_index_index_finished/1
    )
  end

  defp handle_fallback(:heavy_indexes_create_logs_address_hash_first_topic_block_number_index_index_finished) do
    set_and_return_migration_status(
      CreateLogsAddressHashFirstTopicBlockNumberIndexIndex,
      &set_heavy_indexes_create_logs_address_hash_first_topic_block_number_index_index_finished/1
    )
  end

  defp handle_fallback(:heavy_indexes_drop_token_transfers_block_number_asc_log_index_asc_index_finished) do
    set_and_return_migration_status(
      DropTokenTransfersBlockNumberAscLogIndexAscIndex,
      &set_heavy_indexes_drop_token_transfers_block_number_asc_log_index_asc_index_finished/1
    )
  end

  defp handle_fallback(:heavy_indexes_drop_token_transfers_from_address_hash_transaction_hash_index_finished) do
    set_and_return_migration_status(
      DropTokenTransfersFromAddressHashTransactionHashIndex,
      &set_heavy_indexes_drop_token_transfers_from_address_hash_transaction_hash_index_finished/1
    )
  end

  defp handle_fallback(:heavy_indexes_drop_token_transfers_to_address_hash_transaction_hash_index_finished) do
    set_and_return_migration_status(
      DropTokenTransfersToAddressHashTransactionHashIndex,
      &set_heavy_indexes_drop_token_transfers_to_address_hash_transaction_hash_index_finished/1
    )
  end

  defp handle_fallback(:heavy_indexes_drop_token_transfers_token_contract_address_hash_transaction_hash_index_finished) do
    set_and_return_migration_status(
      DropTokenTransfersTokenContractAddressHashTransactionHashIndex,
      &set_heavy_indexes_drop_token_transfers_token_contract_address_hash_transaction_hash_index_finished/1
    )
  end

  defp handle_fallback(:heavy_indexes_drop_token_transfers_block_number_index_finished) do
    set_and_return_migration_status(
      DropTokenTransfersBlockNumberIndex,
      &set_heavy_indexes_drop_token_transfers_block_number_index_finished/1
    )
  end

  defp handle_fallback(:heavy_indexes_drop_internal_transactions_from_address_hash_index_finished) do
    set_and_return_migration_status(
      DropInternalTransactionsFromAddressHashIndex,
      &set_heavy_indexes_drop_internal_transactions_from_address_hash_index_finished/1
    )
  end

  defp handle_fallback(
         :heavy_indexes_create_internal_transactions_block_number_desc_transaction_index_desc_index_desc_index_finished
       ) do
    set_and_return_migration_status(
      CreateInternalTransactionsBlockNumberDescTransactionIndexDescIndexDescIndex,
      &set_heavy_indexes_create_internal_transactions_block_number_desc_transaction_index_desc_index_desc_index_finished/1
    )
  end

  defp handle_fallback(:heavy_indexes_create_addresses_verified_hash_index_finished) do
    set_and_return_migration_status(
      CreateAddressesVerifiedHashIndex,
      &set_heavy_indexes_create_addresses_verified_hash_index_finished/1
    )
  end

  defp handle_fallback(:heavy_indexes_create_addresses_verified_transactions_count_desc_hash_index_finished) do
    set_and_return_migration_status(
      CreateAddressesVerifiedTransactionsCountDescHashIndex,
      &set_heavy_indexes_create_addresses_verified_transactions_count_desc_hash_index_finished/1
    )
  end

  defp handle_fallback(:heavy_indexes_create_addresses_verified_fetched_coin_balance_desc_hash_index_finished) do
    set_and_return_migration_status(
      CreateAddressesVerifiedFetchedCoinBalanceDescHashIndex,
      &set_heavy_indexes_create_addresses_verified_fetched_coin_balance_desc_hash_index_finished/1
    )
  end

  defp handle_fallback(:heavy_indexes_create_smart_contracts_language_index_finished) do
    set_and_return_migration_status(
      CreateSmartContractsLanguageIndex,
      &set_heavy_indexes_create_smart_contracts_language_index_finished/1
    )
  end

  defp handle_fallback(:heavy_indexes_drop_transactions_created_contract_address_hash_with_pending_index) do
    set_and_return_migration_status(
      DropTransactionsCreatedContractAddressHashWithPendingIndex,
      &set_heavy_indexes_drop_transactions_created_contract_address_hash_with_pending_index_finished/1
    )
  end

  defp handle_fallback(:heavy_indexes_drop_transactions_from_address_hash_with_pending_index) do
    set_and_return_migration_status(
      DropTransactionsFromAddressHashWithPendingIndex,
      &set_heavy_indexes_drop_transactions_from_address_hash_with_pending_index_finished/1
    )
  end

  defp handle_fallback(:heavy_indexes_drop_transactions_to_address_hash_with_pending_index) do
    set_and_return_migration_status(
      DropTransactionsToAddressHashWithPendingIndex,
      &set_heavy_indexes_drop_transactions_to_address_hash_with_pending_index_finished/1
    )
  end

  defp handle_fallback(:heavy_indexes_create_logs_deposits_withdrawals_index_finished) do
    set_and_return_migration_status(
      CreateLogsDepositsWithdrawalsIndex,
      &set_heavy_indexes_create_logs_deposits_withdrawals_index_finished/1
    )
  end

  defp handle_fallback(:arbitrum_da_records_normalization_finished) do
    set_and_return_migration_status(
      ArbitrumDaRecordsNormalization,
      &set_arbitrum_da_records_normalization_finished/1
    )
  end

  defp handle_fallback(:smart_contract_language_finished) do
    set_and_return_migration_status(
      SmartContractLanguage,
      &set_smart_contract_language_finished/1
    )
  end

  defp handle_fallback(:heavy_indexes_create_arbitrum_batch_l2_blocks_unconfirmed_blocks_index_finished) do
    set_and_return_migration_status(
      CreateArbitrumBatchL2BlocksUnconfirmedBlocksIndex,
      &set_heavy_indexes_create_arbitrum_batch_l2_blocks_unconfirmed_blocks_index_finished/1
    )
  end

  defp handle_fallback(:heavy_indexes_create_addresses_transactions_count_desc_partial_index_finished) do
    set_and_return_migration_status(
      CreateAddressesTransactionsCountDescPartialIndex,
      &set_heavy_indexes_create_addresses_transactions_count_desc_partial_index_finished/1
    )
  end

  defp handle_fallback(
         :heavy_indexes_create_addresses_transactions_count_asc_coin_balance_desc_hash_partial_index_finished
       ) do
    set_and_return_migration_status(
      CreateAddressesTransactionsCountAscCoinBalanceDescHashPartialIndex,
      &set_heavy_indexes_create_addresses_transactions_count_asc_coin_balance_desc_hash_partial_index_finished/1
    )
  end

  defp handle_fallback(:heavy_indexes_drop_token_instances_token_id_index_finished) do
    set_and_return_migration_status(
      DropTokenInstancesTokenIdIndex,
      &set_heavy_indexes_drop_token_instances_token_id_index_finished/1
    )
  end

  defp handle_fallback(:heavy_indexes_drop_internal_transactions_created_contract_address_hash_partial_index_finished) do
    set_and_return_migration_status(
      DropInternalTransactionsCreatedContractAddressHashPartialIndex,
      &set_heavy_indexes_drop_internal_transactions_created_contract_address_hash_partial_index_finished/1
    )
  end

  defp handle_fallback(:heavy_indexes_create_tokens_name_partial_fts_index_finished) do
    set_and_return_migration_status(
      CreateTokensNamePartialFtsIndex,
      &set_heavy_indexes_create_tokens_name_partial_fts_index_finished/1
    )
  end

  defp handle_fallback(:heavy_indexes_update_internal_transactions_primary_key_finished) do
    set_and_return_migration_status(
      UpdateInternalTransactionsPrimaryKey,
      &set_heavy_indexes_update_internal_transactions_primary_key_finished/1
    )
  end

  defp handle_fallback(:empty_internal_transactions_data_finished) do
    set_and_return_migration_status(
      EmptyInternalTransactionsData,
      &set_empty_internal_transactions_data_finished/1
    )
  end

  defp handle_fallback(:sanitize_verified_addresses_finished) do
    {:return, false}
  end

  defp set_and_return_migration_status(migration_module, status_setter) do
    status = migration_module.migration_finished?()

    status_setter.(status)

    {:return, status}
  end
end
