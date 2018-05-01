# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.
use Mix.Config

config :ethereumex, url: "http://localhost:8545"

# General application configuration
config :explorer,
  ecto_repos: [Explorer.Repo],
  coin: "POA"

config :explorer, :ethereum, backend: Explorer.Ethereum.Live

config :explorer, Explorer.Integrations.EctoLogger, query_time_ms_threshold: 2_000

config :exq,
  host: "localhost",
  port: 6379,
  namespace: "exq",
  start_on_application: false,
  scheduler_enable: true,
  shutdown_timeout: 5000,
  max_retries: 10,
  queues: [
    {"default", 1},
    {"balances", 1},
    {"blocks", 1},
    {"internal_transactions", 1},
    {"transactions", 1},
    {"receipts", 1}
  ]

config :exq_ui, server: false

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
