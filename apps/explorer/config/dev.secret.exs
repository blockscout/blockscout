use Mix.Config

# Configure your database
config :explorer, Explorer.Repo,
  adapter: Ecto.Adapters.Postgres,
  database: "explorer",
  hostname: "blockchainexplorerdata.cbuqrrbjabbr.us-east-1.rds.amazonaws.com",
  username: "springrole",
  password: "springrole1",
  loggers: [Explorer.Repo.PrometheusLogger],
  pool_size: 20,
  pool_timeout: 60_000,
  timeout: 80_000
