use Mix.Config

# Do not log Statistics queries on development mode.
config :explorer, Explorer.Chain.Statistics.Server, enabled: false

# Configure your database
config :explorer, Explorer.Repo,
  adapter: Ecto.Adapters.Postgres,
  database: "explorer_dev",
  hostname: "localhost",
  pool_size: 20,
  pool_timeout: 60_000,
  timeout: 80_000

import_config "dev.secret.exs"

variant = System.get_env("ETHEREUM_JSONRPC_VARIANT") || "parity"

# Import variant specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "dev/#{variant}.exs"
