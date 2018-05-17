use Mix.Config

# Configure your database
config :explorer, Explorer.Repo,
  adapter: Ecto.Adapters.Postgres,
  database: "ewasm",
  username: "ewasm",
  password: "2007109",
  hostname: "localhost",
  loggers: [],
  pool_size: 20,
  pool_timeout: 60_000

import_config "dev.secret.exs"
