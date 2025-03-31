import Config

alias EthereumJSONRPC.Variant

config :explorer, Explorer.ExchangeRates, enabled: false, store: :ets, fetch_btc_value: true

config :explorer, Explorer.ExchangeRates.TokenExchangeRates, enabled: false

config :explorer, Explorer.Chain.Cache.BlockNumber, enabled: false

config :explorer, Explorer.Chain.Cache.Counters.AverageBlockTime, enabled: false

# This historian is a GenServer whose init uses a Repo in a Task process.
# This causes a ConnectionOwnership error
config :explorer, Explorer.Chain.Transaction.History.Historian, enabled: false
config :explorer, Explorer.Market.History.Historian, enabled: false

for counter <- [
      Explorer.Chain.Cache.Counters.AddressesCount,
      Explorer.Chain.Cache.Counters.Optimism.LastOutputRootSizeCount,
      Explorer.Chain.Cache.Counters.Transactions24hCount,
      Explorer.Chain.Cache.Counters.NewPendingTransactionsCount,
      Explorer.Chain.Cache.Counters.ContractsCount,
      Explorer.Chain.Cache.Counters.NewContractsCount,
      Explorer.Chain.Cache.Counters.VerifiedContractsCount,
      Explorer.Chain.Cache.Counters.NewVerifiedContractsCount,
      Explorer.Chain.Cache.Counters.WithdrawalsSum
    ] do
  config :explorer, counter,
    enabled: false,
    enable_consolidation: false
end

config :explorer, Explorer.Chain.Cache.Counters.Rootstock.LockedBTCCount,
  enabled: true,
  global_ttl: :timer.minutes(10),
  locking_cap: 21_000_000

config :explorer, Explorer.Market.History.Cataloger, enabled: false
config :explorer, Explorer.SmartContract.CertifiedSmartContractCataloger, enabled: false

config :explorer, Explorer.Tracer, disabled?: false

config :explorer, Explorer.TokenInstanceOwnerAddressMigration.Supervisor, enabled: false

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
      Explorer.Migrator.ShrinkInternalTransactions,
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
      Explorer.Migrator.HeavyDbIndexOperation.DropTransactionsToAddressHashWithPendingIndex
    ] do
  config :explorer, migrator, enabled: false
end

config :explorer,
  realtime_events_sender: Explorer.Chain.Events.SimpleSender

variant = Variant.get()

Code.require_file("#{variant}.exs", "#{__DIR__}/../../../explorer/config/test")
Code.require_file("#{variant}.exs", "#{__DIR__}/../../../indexer/config/test")
