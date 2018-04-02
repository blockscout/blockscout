use Mix.Config

# Configure your database
config :explorer, Explorer.Repo,
  adapter: Ecto.Adapters.Postgres,
  database: "explorer_dev",
  hostname: "localhost",
  loggers: [],
  pool_size: 10

import_config "dev.secret.exs"
