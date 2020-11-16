# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

import Bitwise

block_transformers = %{
  "clique" => Indexer.Transform.Blocks.Clique,
  "celo" => Indexer.Transform.Blocks.Celo,
  "base" => Indexer.Transform.Blocks.Base
}

# Compile time environment variable access requires recompilation.
configured_transformer = System.get_env("BLOCK_TRANSFORMER") || "celo"

port =
  case System.get_env("PORT") && Integer.parse(System.get_env("PORT")) do
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

max_skipping_distance =
  case Integer.parse(System.get_env("MAX_SKIPPING_DISTANCE", "")) do
    {num, ""} -> num
    _ -> 5
  end

config :indexer, :stacktrace_depth, 20

:erlang.system_flag(:backtrace_depth, 20)

config :indexer,
  block_transformer: block_transformer,
  ecto_repos: [Explorer.Repo],
  metadata_updater_seconds_interval:
    String.to_integer(System.get_env("TOKEN_METADATA_UPDATE_INTERVAL") || "#{10 * 60 * 60}"),
  # bytes
  memory_limit: 1 <<< 32,
  health_check_port: port || 4000,
  first_block: System.get_env("FIRST_BLOCK") || "0",
  last_block: System.get_env("LAST_BLOCK") || "",
  max_skipping_distance: max_skipping_distance

# config :indexer, Indexer.Fetcher.ReplacedTransaction.Supervisor, disabled?: true
# config :indexer, Indexer.Fetcher.BlockReward.Supervisor, disabled?: true
config :indexer, Indexer.Fetcher.StakingPools.Supervisor, disabled?: true

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

config :logger, :indexer, backends: [LoggerJSON]

# config :logger, :indexer,
#  # keep synced with `config/config.exs`
#  format: "$dateT$time $metadata[$level] $message\n",
#  metadata:
#    ~w(application fetcher request_id first_block_number last_block_number missing_block_range_count missing_block_count
#       block_number step count error_count shrunk import_id transaction_id)a,
#  metadata_filter: [application: :indexer]

config :indexer, Indexer.Block.Fetcher, enable_gold_token: true

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
