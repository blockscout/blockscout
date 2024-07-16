import Config

alias EthereumJSONRPC.Variant

config :explorer, Explorer.ExchangeRates, enabled: false, store: :ets, fetch_btc_value: true

config :explorer, Explorer.ExchangeRates.TokenExchangeRates, enabled: false

config :explorer, Explorer.Chain.Cache.BlockNumber, enabled: false

config :explorer, Explorer.Counters.AverageBlockTime, enabled: false

config :explorer, Explorer.Counters.AddressesWithBalanceCounter, enabled: false, enable_consolidation: false

# This historian is a GenServer whose init uses a Repo in a Task process.
# This causes a ConnectionOwnership error
config :explorer, Explorer.Chain.Transaction.History.Historian, enabled: false
config :explorer, Explorer.Market.History.Historian, enabled: false

config :explorer, Explorer.Counters.AddressesCounter, enabled: false, enable_consolidation: false
config :explorer, Explorer.Counters.LastOutputRootSizeCounter, enabled: false, enable_consolidation: false
config :explorer, Explorer.Counters.Transactions24hStats, enabled: false, enable_consolidation: false
config :explorer, Explorer.Counters.FreshPendingTransactionsCounter, enabled: false, enable_consolidation: false
config :explorer, Explorer.Chain.Cache.ContractsCounter, enabled: false, enable_consolidation: false
config :explorer, Explorer.Chain.Cache.NewContractsCounter, enabled: false, enable_consolidation: false
config :explorer, Explorer.Chain.Cache.VerifiedContractsCounter, enabled: false, enable_consolidation: false
config :explorer, Explorer.Chain.Cache.NewVerifiedContractsCounter, enabled: false, enable_consolidation: false
config :explorer, Explorer.Chain.Cache.WithdrawalsSum, enabled: false, enable_consolidation: false

config :explorer, Explorer.Chain.Cache.RootstockLockedBTC,
  enabled: true,
  global_ttl: :timer.minutes(10),
  locking_cap: 21_000_000

config :explorer, Explorer.Market.History.Cataloger, enabled: false

config :explorer, Explorer.Tracer, disabled?: false

config :explorer, Explorer.TokenInstanceOwnerAddressMigration.Supervisor, enabled: false

config :explorer, Explorer.Migrator.TransactionsDenormalization, enabled: false
config :explorer, Explorer.Migrator.AddressCurrentTokenBalanceTokenType, enabled: false
config :explorer, Explorer.Migrator.AddressTokenBalanceTokenType, enabled: false
config :explorer, Explorer.Migrator.SanitizeMissingBlockRanges, enabled: false
config :explorer, Explorer.Migrator.SanitizeIncorrectNFTTokenTransfers, enabled: false
config :explorer, Explorer.Migrator.TokenTransferTokenType, enabled: false
config :explorer, Explorer.Migrator.SanitizeIncorrectWETHTokenTransfers, enabled: false
config :explorer, Explorer.Migrator.TransactionBlockConsensus, enabled: false
config :explorer, Explorer.Migrator.TokenTransferBlockConsensus, enabled: false

config :explorer,
  realtime_events_sender: Explorer.Chain.Events.SimpleSender

variant = Variant.get()

Code.require_file("#{variant}.exs", "#{__DIR__}/../../../explorer/config/test")
Code.require_file("#{variant}.exs", "#{__DIR__}/../../../indexer/config/test")
