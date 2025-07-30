# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.
import Config

[__DIR__ | ~w(.. .. .. config config_helper.exs)]
|> Path.join()
|> Code.eval_file()

# General application configuration
config :explorer,
  chain_type: ConfigHelper.chain_type(),
  ecto_repos: ConfigHelper.repos(),
  token_functions_reader_max_retries: 3,
  # for not fully indexed blockchains
  decode_not_a_contract_calls: ConfigHelper.parse_bool_env_var("DECODE_NOT_A_CONTRACT_CALLS")

config :explorer, Explorer.ChainSpec.GenesisData, enabled: true

config :explorer, Explorer.Chain.Cache.BlockNumber, enabled: true

config :explorer, Explorer.Chain.Cache.Counters.AddressesCoinBalanceSum,
  enabled: true,
  ttl_check_interval: :timer.seconds(1)

config :explorer, Explorer.Chain.Cache.Counters.AddressesCoinBalanceSumMinusBurnt,
  enabled: true,
  ttl_check_interval: :timer.seconds(1)

config :explorer, Explorer.Chain.Cache.Counters.AddressesCount,
  enabled: true,
  enable_consolidation: true

config :explorer, Explorer.Chain.Cache.Counters.AddressTransactionsGasUsageSum,
  enabled: true,
  enable_consolidation: true

config :explorer, Explorer.Chain.Cache.Counters.AddressTokensUsdSum,
  enabled: true,
  enable_consolidation: true

update_interval_in_milliseconds_default = 30 * 60 * 1000

config :explorer, Explorer.Chain.Cache.Counters.ContractsCount,
  enabled: true,
  enable_consolidation: true,
  update_interval_in_milliseconds: update_interval_in_milliseconds_default

config :explorer, Explorer.Chain.Cache.Counters.NewContractsCount,
  enabled: true,
  enable_consolidation: true,
  update_interval_in_milliseconds: update_interval_in_milliseconds_default

config :explorer, Explorer.Chain.Cache.Counters.VerifiedContractsCount,
  enabled: true,
  enable_consolidation: true,
  update_interval_in_milliseconds: update_interval_in_milliseconds_default

config :explorer, Explorer.Chain.Cache.Counters.NewVerifiedContractsCount,
  enabled: true,
  enable_consolidation: true,
  update_interval_in_milliseconds: update_interval_in_milliseconds_default

config :explorer, Explorer.Chain.Cache.Counters.WithdrawalsSum,
  enabled: true,
  enable_consolidation: true,
  update_interval_in_milliseconds: update_interval_in_milliseconds_default

config :explorer, Explorer.Chain.Cache.Counters.Stability.ValidatorsCount,
  enabled: true,
  enable_consolidation: true,
  update_interval_in_milliseconds: update_interval_in_milliseconds_default

config :explorer, Explorer.Chain.Cache.Counters.Blackfort.ValidatorsCount,
  enabled: true,
  enable_consolidation: true,
  update_interval_in_milliseconds: update_interval_in_milliseconds_default

config :explorer, Explorer.Chain.Cache.TransactionActionTokensData, enabled: true

config :explorer, Explorer.Chain.Cache.TransactionActionUniswapPools, enabled: true

config :explorer, Explorer.Market.Fetcher.Token, enabled: true

config :explorer, Explorer.Chain.Cache.Counters.TokenHoldersCount,
  enabled: true,
  enable_consolidation: true

config :explorer, Explorer.Chain.Cache.Counters.TokenTransfersCount,
  enabled: true,
  enable_consolidation: true

config :explorer, Explorer.Chain.Cache.Counters.AddressTransactionsCount,
  enabled: true,
  enable_consolidation: true

config :explorer, Explorer.Chain.Cache.Counters.AddressTokenTransfersCount,
  enabled: true,
  enable_consolidation: true

config :explorer, Explorer.Chain.Cache.Counters.BlockBurntFeeCount,
  enabled: true,
  enable_consolidation: true

config :explorer, Explorer.Chain.Cache.Counters.BlockPriorityFeeCount,
  enabled: true,
  enable_consolidation: true

config :explorer, Explorer.TokenInstanceOwnerAddressMigration.Supervisor, enabled: true

for migrator <- [
      # Background migrations
      Explorer.Migrator.TransactionsDenormalization,
      Explorer.Migrator.AddressCurrentTokenBalanceTokenType,
      Explorer.Migrator.AddressTokenBalanceTokenType,
      Explorer.Migrator.SanitizeMissingBlockRanges,
      Explorer.Migrator.SanitizeIncorrectNFTTokenTransfers,
      Explorer.Migrator.TokenTransferTokenType,
      Explorer.Migrator.SanitizeIncorrectWETHTokenTransfers,
      Explorer.Migrator.TransactionBlockConsensus,
      Explorer.Migrator.TokenTransferBlockConsensus,
      Explorer.Migrator.RestoreOmittedWETHTransfers,
      Explorer.Migrator.SanitizeMissingTokenBalances,
      Explorer.Migrator.SanitizeReplacedTransactions,
      Explorer.Migrator.ReindexInternalTransactionsWithIncompatibleStatus,
      Explorer.Migrator.SanitizeDuplicatedLogIndexLogs,
      Explorer.Migrator.RefetchContractCodes,
      Explorer.Migrator.BackfillMultichainSearchDB,
      Explorer.Migrator.SanitizeVerifiedAddresses,
      Explorer.Migrator.SmartContractLanguage,
      Explorer.Migrator.SanitizeEmptyContractCodeAddresses,
      Explorer.Migrator.BackfillMetadataURL,
      Explorer.Migrator.SanitizeErc1155TokenBalancesWithoutTokenIds,
      Explorer.Migrator.ReindexDuplicatedInternalTransactions,
      Explorer.Migrator.MergeAdjacentMissingBlockRanges
    ] do
  config :explorer, migrator, enabled: true
end

for index_operation <- [
      # Heavy DB index operations
      Explorer.Migrator.HeavyDbIndexOperation.CreateLogsBlockHashIndex,
      Explorer.Migrator.HeavyDbIndexOperation.DropLogsBlockNumberAscIndexAscIndex,
      Explorer.Migrator.HeavyDbIndexOperation.CreateLogsAddressHashBlockNumberDescIndexDescIndex,
      Explorer.Migrator.HeavyDbIndexOperation.DropLogsAddressHashIndex,
      Explorer.Migrator.HeavyDbIndexOperation.DropLogsAddressHashTransactionHashIndex,
      Explorer.Migrator.HeavyDbIndexOperation.DropLogsIndexIndex,
      Explorer.Migrator.HeavyDbIndexOperation.CreateLogsAddressHashFirstTopicBlockNumberIndexIndex,
      Explorer.Migrator.HeavyDbIndexOperation.DropInternalTransactionsFromAddressHashIndex,
      Explorer.Migrator.HeavyDbIndexOperation.CreateInternalTransactionsBlockNumberDescTransactionIndexDescIndexDescIndex,
      Explorer.Migrator.HeavyDbIndexOperation.DropTokenTransfersBlockNumberAscLogIndexAscIndex,
      Explorer.Migrator.HeavyDbIndexOperation.DropTokenTransfersFromAddressHashTransactionHashIndex,
      Explorer.Migrator.HeavyDbIndexOperation.DropTokenTransfersToAddressHashTransactionHashIndex,
      Explorer.Migrator.HeavyDbIndexOperation.DropTokenTransfersTokenContractAddressHashTransactionHashIndex,
      Explorer.Migrator.HeavyDbIndexOperation.DropTokenTransfersBlockNumberIndex,
      Explorer.Migrator.HeavyDbIndexOperation.CreateAddressesVerifiedIndex,
      Explorer.Migrator.HeavyDbIndexOperation.DropAddressesVerifiedIndex,
      Explorer.Migrator.HeavyDbIndexOperation.CreateAddressesVerifiedHashIndex,
      Explorer.Migrator.HeavyDbIndexOperation.CreateAddressesVerifiedTransactionsCountDescHashIndex,
      Explorer.Migrator.HeavyDbIndexOperation.CreateAddressesVerifiedFetchedCoinBalanceDescHashIndex,
      Explorer.Migrator.HeavyDbIndexOperation.CreateSmartContractsLanguageIndex,
      Explorer.Migrator.HeavyDbIndexOperation.DropTransactionsCreatedContractAddressHashWithPendingIndex,
      Explorer.Migrator.HeavyDbIndexOperation.DropTransactionsFromAddressHashWithPendingIndex,
      Explorer.Migrator.HeavyDbIndexOperation.DropTransactionsToAddressHashWithPendingIndex,
      Explorer.Migrator.HeavyDbIndexOperation.CreateLogsDepositsWithdrawalsIndex,
      Explorer.Migrator.HeavyDbIndexOperation.CreateAddressesTransactionsCountDescPartialIndex,
      Explorer.Migrator.HeavyDbIndexOperation.CreateAddressesTransactionsCountAscCoinBalanceDescHashPartialIndex,
      Explorer.Migrator.HeavyDbIndexOperation.CreateInternalTransactionsBlockHashTransactionIndexIndexUniqueIndex
    ] do
  config :explorer, index_operation, enabled: true
end

config :explorer, Explorer.Chain.Fetcher.CheckBytecodeMatchingOnDemand, enabled: true

config :explorer, Explorer.Chain.Fetcher.FetchValidatorInfoOnDemand, enabled: true

config :explorer, Explorer.Integrations.EctoLogger, query_time_ms_threshold: :timer.seconds(2)

config :explorer, Explorer.Tags.AddressTag.Cataloger, enabled: true

config :explorer, Explorer.SmartContract.CertifiedSmartContractCataloger, enabled: true

config :explorer, Explorer.Utility.RateLimiter, enabled: true

config :explorer, Explorer.Utility.Hammer.Redis, enabled: true
config :explorer, Explorer.Utility.Hammer.ETS, enabled: true

config :explorer, Explorer.Repo, migration_timestamps: [type: :utc_datetime_usec]

config :explorer, Explorer.Tracer,
  service: :explorer,
  adapter: SpandexDatadog.Adapter,
  trace_key: :blockscout

config :explorer,
  solc_bin_api_url: "https://solc-bin.ethereum.org"

config :explorer, :http_client, Explorer.HttpClient.Tesla

config :explorer, Explorer.Chain.BridgedToken, enabled: ConfigHelper.parse_bool_env_var("BRIDGED_TOKENS_ENABLED")

config :logger, :explorer,
  # keep synced with `config/config.exs`
  format: "$dateT$time $metadata[$level] $message\n",
  metadata:
    ~w(application fetcher request_id first_block_number last_block_number missing_block_range_count missing_block_count
       block_number step count error_count shrunk import_id transaction_id)a,
  metadata_filter: [application: :explorer]

config :spandex_ecto, SpandexEcto.EctoLogger,
  service: :ecto,
  tracer: Explorer.Tracer,
  otp_app: :explorer

config :tesla, adapter: Tesla.Adapter.Mint

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
