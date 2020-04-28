use Mix.Config

config :indexer, Indexer.Tracer, disabled?: false

config :indexer, Indexer.Fetcher.CeloValidatorHistory.Supervisor, disabled?: true

# Disable reading native coin to gold token 
# TODO: write a test where gold token is in
config :indexer, Indexer.Block.Fetcher, enable_gold_token: false

config :indexer,
  block_transformer: Indexer.Transform.Blocks.Base

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
