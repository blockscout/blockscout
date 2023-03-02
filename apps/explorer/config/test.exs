import Config

# Lower hashing rounds for faster tests
config :bcrypt_elixir, log_rounds: 4

# Configure your database
config :explorer, Explorer.Repo,
  database: "explorer_test",
  hostname: "localhost",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 30,
  # Default of `5_000` was too low for `BlockFetcher` test
  ownership_timeout: :timer.minutes(7),
  timeout: :timer.seconds(60),
  queue_target: 1000,
  migration_lock: nil

# Configure API database
config :explorer, Explorer.Repo.Replica1,
  database: "explorer_test",
  hostname: "localhost",
  pool: Ecto.Adapters.SQL.Sandbox,
  # Default of `5_000` was too low for `BlockFetcher` test
  ownership_timeout: :timer.minutes(1),
  timeout: :timer.seconds(60),
  queue_target: 1000,
  enable_caching_implementation_data_of_proxy: true,
  avg_block_time_as_ttl_cached_implementation_data_of_proxy: false,
  fallback_ttl_cached_implementation_data_of_proxy: :timer.seconds(20),
  implementation_data_fetching_timeout: :timer.seconds(20)

# Configure API database
config :explorer, Explorer.Repo.Account,
  database: "explorer_test_account",
  hostname: "localhost",
  pool: Ecto.Adapters.SQL.Sandbox,
  # Default of `5_000` was too low for `BlockFetcher` test
  ownership_timeout: :timer.minutes(1),
  timeout: :timer.seconds(60),
  queue_target: 1000

config :logger, :explorer,
  level: :warn,
  path: Path.absname("logs/test/explorer.log")

config :explorer, Explorer.ExchangeRates.Source.TransactionAndLog,
  secondary_source: Explorer.ExchangeRates.Source.OneCoinSource

config :explorer, Explorer.Chain.Fetcher.CheckBytecodeMatchingOnDemand, enabled: false
