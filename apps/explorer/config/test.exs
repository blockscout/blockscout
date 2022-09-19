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
  queue_target: 1000

# Configure API database
config :explorer, Explorer.Repo.Replica1,
  database: "explorer_test",
  hostname: "localhost",
  pool: Ecto.Adapters.SQL.Sandbox,
  # Default of `5_000` was too low for `BlockFetcher` test
  ownership_timeout: :timer.minutes(1),
  timeout: :timer.seconds(60),
  queue_target: 1000

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
