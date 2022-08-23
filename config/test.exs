import Config

# Print only warnings and errors during test

config :logger, :console, level: :warn

config :logger, :ecto,
  level: :warn,
  path: Path.absname("logs/test/ecto.log")

config :logger, :error, path: Path.absname("logs/test/error.log")

config :explorer, Explorer.ExchangeRates,
  source: Explorer.ExchangeRates.Source.NoOpSource,
  store: :none

config :explorer, Explorer.KnownTokens, store: :none

config :explorer, Explorer.Repo,
  adapter: Ecto.Adapters.Postgres,
  username: "postgres",
  password: "1234",
  database: "explorer_test",
  hostname: "localhost",
  poolsize: 10,
  # Ensure async testing is possible:
  pool: Ecto.Adapters.SQL.Sandbox,
  # disable ecto logs during test
  log: false
