use Mix.Config

# Configure your database
config :explorer, Explorer.Repo,
  adapter: Ecto.Adapters.Postgres,
  database: "explorer_dev",
  hostname: "localhost",
  loggers: [],
  pool_size: 20,
  pool_timeout: 60_000,
  # Default value of 15_000 causes timeouts around block 813200
  timeout: 60_000

import_config "dev.secret.exs"
