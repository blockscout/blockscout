# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.
use Mix.Config

config :explorer, :indexer,
  block_rate: 5_000,
  debug_logs: !!System.get_env("DEBUG_INDEXER")

# General application configuration
config :explorer,
  ecto_repos: [Explorer.Repo],
  coin: "POA"

config :explorer, Explorer.Integrations.EctoLogger, query_time_ms_threshold: 2_000

config :explorer, Explorer.Chain.Statistics.Server, enabled: true

config :explorer, Explorer.ExchangeRates, enabled: true

config :explorer, Explorer.Indexer.Supervisor, enabled: true

config :explorer, Explorer.Market.History.Cataloger, enabled: true

config :explorer, Explorer.Repo, migration_timestamps: [type: :utc_datetime]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
