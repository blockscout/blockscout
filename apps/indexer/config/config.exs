# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

import Bitwise

config :indexer,
  block_transformer: Indexer.Block.Transform.Base,
  ecto_repos: [Explorer.Repo],
  metadata_updater_days_interval: 7,
  # bytes
  memory_limit: 1 <<< 30

config :indexer, Indexer.Tracer,
  service: :indexer,
  adapter: SpandexDatadog.Adapter,
  trace_key: :blockscout

config :logger, :indexer,
  # keep synced with `config/config.exs`
  format: "$dateT$time $metadata[$level] $message\n",
  metadata: ~w(application fetcher block_number count error_count first_block_number last_block_number microseconds
       missing_block_count shrunk step import_id request_id transaction_id)a,
  metadata_filter: [application: :indexer]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
