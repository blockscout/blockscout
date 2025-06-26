import Config

config :indexer, Indexer.Tracer, disabled?: false

config :indexer, Indexer.Block.Catchup.MissingRangesCollector, future_check_interval: 1

config :indexer, Indexer.Migrator.RecoveryWETHTokenTransfers, enabled: false

config :logger, :indexer,
  level: :warn,
  path: Path.absname("logs/test/indexer.log")

config :logger, :indexer_token_balances,
  level: :debug,
  path: Path.absname("logs/test/indexer/token_balances/error.log"),
  metadata_filter: [fetcher: :token_balances]

config :logger, :failed_contract_creations,
  level: :debug,
  path: Path.absname("logs/test/indexer/failed_contract_creations.log"),
  metadata_filter: [fetcher: :failed_created_addresses]

config :logger, :addresses_without_code,
  level: :debug,
  path: Path.absname("logs/test/indexer/addresses_without_code.log"),
  metadata_filter: [fetcher: :addresses_without_code]
