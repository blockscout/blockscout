use Mix.Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :explorer, ExplorerWeb.Endpoint,
  http: [port: 4001],
  secret_key_base: "27Swe6KtEtmN37WyEYRjKWyxYULNtrxlkCEKur4qoV+Lwtk8lafsR16ifz1XBBYj",
  server: true

config :explorer, :sql_sandbox, true

# Print only warnings and errors during test
config :logger, level: :warn

# Configure your database
config :explorer, Explorer.Repo,
  adapter: Ecto.Adapters.Postgres,
  database: "explorer_test",
  hostname: "localhost",
  pool: Ecto.Adapters.SQL.Sandbox,
  ownership_timeout: 30_000

# Configure wallaby
config :wallaby,
  screenshot_on_failure: true

# Configure ethereumex
config :ethereumex,
  scheme: "https",
  host: "sokol.poa.network",
  port: 443
