use Mix.Config

config :indexer, Indexer.Tracer, disabled?: false

config :logger, :indexer,
  level: :warn,
  path: Path.absname("logs/test/indexer.log")

config :logger, :indexer_token_balances,
  level: :debug,
  path: Path.absname("logs/test/indexer/token_balances/error.log"),
  metadata_filter: [fetcher: :token_balances]
