# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.
use Mix.Config

# General application configuration
config :explorer,
  ecto_repos: [Explorer.Repo],
  coin: System.get_env("COIN") || "DAI",
  token_functions_reader_max_retries: 3

config :explorer, Explorer.Counters.AverageBlockTime, enabled: true

config :explorer, Explorer.Counters.AddressesWithBalanceCounter, enabled: true, enable_consolidation: true

config :explorer, Explorer.ExchangeRates, enabled: true, store: :ets

config :explorer, Explorer.KnownTokens, enabled: true, store: :ets

config :explorer, Explorer.Integrations.EctoLogger, query_time_ms_threshold: :timer.seconds(2)

config :explorer, Explorer.Market.History.Cataloger, enabled: true

config :explorer, Explorer.Repo, migration_timestamps: [type: :utc_datetime_usec]

config :explorer, Explorer.Tracer,
  service: :explorer,
  adapter: SpandexDatadog.Adapter,
  trace_key: :blockscout

if System.get_env("METADATA_CONTRACT") && System.get_env("VALIDATORS_CONTRACT") do
  config :explorer, Explorer.Validator.MetadataRetriever,
    metadata_contract_address: System.get_env("METADATA_CONTRACT"),
    validators_contract_address: System.get_env("VALIDATORS_CONTRACT")

  config :explorer, Explorer.Validator.MetadataProcessor, enabled: true
else
  config :explorer, Explorer.Validator.MetadataProcessor, enabled: false
end

config :explorer, supply: Explorer.Chain.Supply.TransactionAndLog

config :explorer, Explorer.ExchangeRates.Source, source: Explorer.ExchangeRates.Source.TransactionAndLog

config :explorer,
  solc_bin_api_url: "https://solc-bin.ethereum.org"

config :logger, :explorer,
  # keep synced with `config/config.exs`
  format: "$dateT$time $metadata[$level] $message\n",
  metadata:
    ~w(application fetcher request_id first_block_number last_block_number missing_block_range_count missing_block_count
       block_number step count error_count shrunk import_id transaction_id)a,
  metadata_filter: [application: :explorer]

config :spandex_ecto, SpandexEcto.EctoLogger,
  service: :ecto,
  tracer: Explorer.Tracer,
  otp_app: :explorer

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
