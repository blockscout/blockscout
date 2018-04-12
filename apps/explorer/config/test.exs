use Mix.Config

# Configure your database
config :explorer, Explorer.Repo,
  adapter: Ecto.Adapters.Postgres,
  database: "explorer_test",
  hostname: "localhost",
  pool: Ecto.Adapters.SQL.Sandbox,
  ownership_timeout: 60_000

# Configure ethereumex
config :ethereumex, url: "https://sokol-trace.poa.network"

config :explorer, :ethereum, backend: Explorer.Ethereum.Test
