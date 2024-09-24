import Config

# Lower hashing rounds for faster tests
config :bcrypt_elixir, log_rounds: 4

database_url = System.get_env("TEST_DATABASE_URL")
database = if database_url, do: nil, else: "explorer_test"
hostname = if database_url, do: nil, else: "localhost"

# Configure your database
config :explorer, Explorer.Repo,
  database: database,
  hostname: hostname,
  url: database_url,
  pool: Ecto.Adapters.SQL.Sandbox,
  # Default of `5_000` was too low for `BlockFetcher` test
  ownership_timeout: :timer.minutes(7),
  timeout: :timer.seconds(60),
  queue_target: 1000,
  migration_lock: nil,
  log: false

# Configure API database
config :explorer, Explorer.Repo.Replica1,
  database: database,
  hostname: hostname,
  url: database_url,
  pool: Ecto.Adapters.SQL.Sandbox,
  # Default of `5_000` was too low for `BlockFetcher` test
  ownership_timeout: :timer.minutes(1),
  timeout: :timer.seconds(60),
  queue_target: 1000,
  log: false

config :explorer, :proxy,
  caching_implementation_data_enabled: true,
  implementation_data_ttl_via_avg_block_time: false,
  fallback_cached_implementation_data_ttl: :timer.seconds(20),
  implementation_data_fetching_timeout: :timer.seconds(20)

account_database_url = System.get_env("TEST_DATABASE_READ_ONLY_API_URL") || database_url
account_database = if account_database_url, do: nil, else: "explorer_test_account"

# Configure API database
config :explorer, Explorer.Repo.Account,
  database: account_database,
  hostname: hostname,
  url: account_database_url,
  pool: Ecto.Adapters.SQL.Sandbox,
  # Default of `5_000` was too low for `BlockFetcher` test
  ownership_timeout: :timer.minutes(1),
  timeout: :timer.seconds(60),
  queue_target: 1000,
  log: false

for repo <- [
      Explorer.Repo.Beacon,
      Explorer.Repo.Optimism,
      Explorer.Repo.PolygonEdge,
      Explorer.Repo.PolygonZkevm,
      Explorer.Repo.ZkSync,
      Explorer.Repo.Celo,
      Explorer.Repo.RSK,
      Explorer.Repo.Shibarium,
      Explorer.Repo.Suave,
      Explorer.Repo.Arbitrum,
      Explorer.Repo.BridgedTokens,
      Explorer.Repo.Filecoin,
      Explorer.Repo.Stability,
      Explorer.Repo.Mud,
      Explorer.Repo.ShrunkInternalTransactions,
      Explorer.Repo.Blackfort
    ] do
  config :explorer, repo,
    database: database,
    hostname: hostname,
    url: database_url,
    pool: Ecto.Adapters.SQL.Sandbox,
    # Default of `5_000` was too low for `BlockFetcher` test
    ownership_timeout: :timer.minutes(1),
    timeout: :timer.seconds(60),
    queue_target: 1000,
    log: false,
    pool_size: 1
end

config :explorer, Explorer.Repo.PolygonZkevm,
  database: database,
  hostname: hostname,
  url: database_url,
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
config :explorer, Explorer.Chain.Fetcher.FetchValidatorInfoOnDemand, enabled: false
