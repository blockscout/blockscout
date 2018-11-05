# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.
use Mix.Config

config :ecto, json_library: Jason

# General application configuration
config :explorer,
  ecto_repos: [Explorer.Repo],
  coin: System.get_env("COIN") || "ETH"

config :explorer, Explorer.Integrations.EctoLogger, query_time_ms_threshold: 2_000

config :explorer, Explorer.ExchangeRates, enabled: true

config :explorer, Explorer.Counters.BlockValidationCounter, enabled: true

config :explorer, Explorer.Market.History.Cataloger, enabled: true

config :explorer, Explorer.Repo,
  loggers: [Explorer.Repo.PrometheusLogger, Ecto.LogEntry],
  migration_timestamps: [type: :utc_datetime]

config :explorer, Explorer.Counters.TokenTransferCounter, enabled: true

config :explorer, Explorer.Counters.TokenHoldersCounter, enabled: true, enable_consolidation: true

if System.get_env("SUPPLY_MODULE") == "TransactionAndLog" do
  config :explorer, supply: Explorer.Chain.Supply.TransactionAndLog
end

if System.get_env("SOURCE_MODULE") == "TransactionAndLog" do
  config :explorer, Explorer.ExchangeRates, source: Explorer.ExchangeRates.Source.TransactionAndLog
end

config :explorer,
  solc_bin_api_url: "https://solc-bin.ethereum.org"

config :logger, :explorer,
  # keep synced with `config/config.exs`
  format: "$time $metadata[$level] $message\n",
  metadata: [:application, :request_id],
  metadata_filter: [application: :explorer]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
