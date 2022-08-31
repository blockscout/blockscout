# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
import Config

alias Indexer.LoggerBackend

block_transformers = %{
  "clique" => Indexer.Transform.Blocks.Clique,
  "celo" => Indexer.Transform.Blocks.Celo,
  "base" => Indexer.Transform.Blocks.Base
}

# Compile time environment variable access requires recompilation.
configured_transformer = System.get_env("BLOCK_TRANSFORMER") || "celo"

port =
  case System.get_env("HEALTH_CHECK_PORT") && Integer.parse(System.get_env("HEALTH_CHECK_PORT")) do
    {port, _} -> port
    :error -> nil
    nil -> nil
  end

block_transformer =
  case Map.get(block_transformers, configured_transformer) do
    nil ->
      raise """
      No such block transformer: #{configured_transformer}.

      Valid values are:
      #{Enum.join(Map.keys(block_transformers), "\n")}

      Please update environment variable BLOCK_TRANSFORMER accordingly.
      """

    transformer ->
      transformer
  end

config :indexer,
  block_transformer: block_transformer,
  ecto_repos: [Explorer.Repo],
  metadata_updater_seconds_interval:
    String.to_integer(System.get_env("TOKEN_METADATA_UPDATE_INTERVAL") || "#{10 * 60 * 60}"),
  health_check_port: port || 4001,
  first_block: System.get_env("FIRST_BLOCK") || "",
  last_block: System.get_env("LAST_BLOCK") || "",
  metrics_enabled: System.get_env("METRICS_ENABLED") || false

config :indexer, Indexer.Fetcher.PendingTransaction.Supervisor,
  disabled?: System.get_env("ETHEREUM_JSONRPC_VARIANT") == "besu"

token_balance_on_demand_fetcher_threshold =
  if System.get_env("TOKEN_BALANCE_ON_DEMAND_FETCHER_THRESHOLD_MINUTES") do
    case Integer.parse(System.get_env("TOKEN_BALANCE_ON_DEMAND_FETCHER_THRESHOLD_MINUTES")) do
      {integer, ""} -> integer
      _ -> 60
    end
  else
    60
  end

config :indexer, Indexer.Fetcher.TokenBalanceOnDemand, threshold: token_balance_on_demand_fetcher_threshold

# config :indexer, Indexer.Fetcher.ReplacedTransaction.Supervisor, disabled?: true
if System.get_env("POS_STAKING_CONTRACT") do
  config :indexer, Indexer.Fetcher.BlockReward.Supervisor, disabled?: true
end

config :indexer, Indexer.Supervisor, enabled: System.get_env("DISABLE_INDEXER") != "true"

config :indexer, Indexer.Tracer,
  service: :indexer,
  adapter: SpandexDatadog.Adapter,
  trace_key: :blockscout

config :logger_json, :indexer,
  metadata:
    ~w(application fetcher request_id first_block_number last_block_number missing_block_range_count missing_block_count
       block_number step count error_count shrunk import_id transaction_id)a,
  metadata_filter: [application: :indexer]


config :logger, :logger_backend, level: :error
# config :logger, :indexer,
#  # keep synced with `config/config.exs`
#  format: "$dateT$time $metadata[$level] $message\n",
#  metadata:
#    ~w(application fetcher request_id first_block_number last_block_number missing_block_range_count missing_block_count
#       block_number step count error_count shrunk import_id transaction_id)a,
#  metadata_filter: [application: :indexer]

config :indexer, Indexer.Block.Fetcher, enable_gold_token: true
config :indexer, Indexer.Prometheus.MetricsCron, metrics_fetcher_blocks_count: 1000
config :indexer, Indexer.Prometheus.MetricsCron, metrics_cron_interval: System.get_env("METRICS_CRON_INTERVAL") || "2"

config :prometheus, Indexer.Prometheus.Exporter,
  path: "/metrics/indexer",
  format: :text,
  registry: :default

indexer_empty_blocks_sanitizer_batch_size =
  if System.get_env("INDEXER_EMPTY_BLOCKS_SANITIZER_BATCH_SIZE") do
    case Integer.parse(System.get_env("INDEXER_EMPTY_BLOCKS_SANITIZER_BATCH_SIZE")) do
      {integer, ""} -> integer
      _ -> 100
    end
  else
    100
  end

config :indexer, Indexer.Fetcher.EmptyBlocksSanitizer.Supervisor,
  disabled?: System.get_env("INDEXER_DISABLE_EMPTY_BLOCK_SANITIZER", "false") == "true"

config :indexer, Indexer.Fetcher.EmptyBlocksSanitizer, batch_size: indexer_empty_blocks_sanitizer_batch_size

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
