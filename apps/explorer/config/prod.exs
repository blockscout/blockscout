use Mix.Config

# Configures the database
config :explorer, Explorer.Repo,
  adapter: Ecto.Adapters.Postgres,
  url: System.get_env("DATABASE_URL"),
  pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
  ssl: String.equivalent?(System.get_env("ECTO_USE_SSL") || "true", "true"),
  prepare: :unnamed,
  timeout: 60_000

variant = System.get_env("ETHEREUM_JSONRPC_VARIANT") || "parity"

# Import variant specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "prod/#{variant}.exs"
