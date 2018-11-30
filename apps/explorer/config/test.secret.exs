use Mix.Config

# Configure your database
config :explorer, Explorer.Repo,
  adapter: Ecto.Adapters.Postgres,
  database: "explorer_test",
  hostname: "blockchainexplorerdata.cbuqrrbjabbr.us-east-1.rds.amazonaws.com",
  pool: Ecto.Adapters.SQL.Sandbox,
  port: "5432",
  ownership_timeout: 60_000
