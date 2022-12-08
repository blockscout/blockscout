# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
import Config
alias Indexer.Celo.Utils
alias Indexer.LoggerBackend

config :indexer,
  ecto_repos: [Explorer.Repo.Local]

# config :indexer, Indexer.Fetcher.ReplacedTransaction.Supervisor, disabled?: true

config :indexer, Indexer.Tracer,
  service: :indexer,
  adapter: SpandexDatadog.Adapter,
  trace_key: :blockscout

config :logger_json, :indexer,
  metadata:
    ~w(application fetcher request_id first_block_number last_block_number missing_block_range_count missing_block_count
       block_number step count error_count shrunk import_id transaction_id)a,
  metadata_filter: [application: :indexer]

config :logger, :indexer, backends: [LoggerJSON, {LoggerBackend, :logger_backend}]

config :logger, :logger_backend, level: :error
# config :logger, :indexer,
#  # keep synced with `config/config.exs`
#  format: "$dateT$time $metadata[$level] $message\n",
#  metadata:
#    ~w(application fetcher request_id first_block_number last_block_number missing_block_range_count missing_block_count
#       block_number step count error_count shrunk import_id transaction_id)a,
#  metadata_filter: [application: :indexer]

import_config "telemetry/telemetry.exs"

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
