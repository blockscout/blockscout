# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
import Config

config :indexer,
  ecto_repos: [Explorer.Repo]

config :indexer, Indexer.Tracer,
  service: :indexer,
  adapter: SpandexDatadog.Adapter,
  trace_key: :blockscout

config :indexer, Indexer.Block.Catchup.MissingRangesCollector, future_check_interval: :timer.minutes(1)

config :indexer, Indexer.Migrator.RecoveryWETHTokenTransfers, enabled: true

config :logger, :indexer,
  metadata: ConfigHelper.logger_metadata(),
  metadata_filter: [application: :indexer]

config :os_mon,
  start_cpu_sup: false,
  start_disksup: false,
  start_memsup: true

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
