use Mix.Config

# Configure your database
config :explorer, Explorer.Repo,
  adapter: Ecto.Adapters.Postgres,
  database: "explorer_test",
  hostname: "localhost",
  pool: Ecto.Adapters.SQL.Sandbox,
  ownership_timeout: 60_000

config :explorer, Explorer.Chain.Statistics.Server, enabled: false

config :explorer, Explorer.ExchangeRates, enabled: false

config :explorer, Explorer.Indexer.Supervisor, enabled: false

config :explorer, Explorer.Market.History.Cataloger, enabled: false
