use Mix.Config

config :indexer, Indexer.Tracer, disabled?: false

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
