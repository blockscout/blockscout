# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

import Bitwise

block_transformers = %{
  "clique" => Indexer.Transform.Blocks.Clique,
  "base" => Indexer.Transform.Blocks.Base
}

# Compile time environment variable access requires recompilation.
configured_transformer = System.get_env("BLOCK_TRANSFORMER") || "base"

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
    String.to_integer(System.get_env("TOKEN_METADATA_UPDATE_INTERVAL") || "#{2 * 24 * 60 * 60}"),
  # bytes
  memory_limit: 10 <<< 30,
  first_block: System.get_env("FIRST_BLOCK") || "",
  last_block: System.get_env("LAST_BLOCK") || "",
  trace_first_block: System.get_env("TRACE_FIRST_BLOCK") || "",
  trace_last_block: System.get_env("TRACE_LAST_BLOCK") || ""

config :indexer, Indexer.Fetcher.PendingTransaction.Supervisor,
  disabled?:
    System.get_env("ETHEREUM_JSONRPC_VARIANT") == "besu" ||
      System.get_env("INDEXER_DISABLE_PENDING_TRANSACTIONS_FETCHER", "false") == "true"

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

coin_balance_on_demand_fetcher_threshold =
  if System.get_env("COIN_BALANCE_ON_DEMAND_FETCHER_THRESHOLD_MINUTES") do
    case Integer.parse(System.get_env("COIN_BALANCE_ON_DEMAND_FETCHER_THRESHOLD_MINUTES")) do
      {integer, ""} -> integer
      _ -> 60
    end
  else
    60
  end

config :indexer, Indexer.Fetcher.CoinBalanceOnDemand, threshold: coin_balance_on_demand_fetcher_threshold

# config :indexer, Indexer.Fetcher.ReplacedTransaction.Supervisor, disabled?: true
if System.get_env("POS_STAKING_CONTRACT") do
  config :indexer, Indexer.Fetcher.BlockReward.Supervisor, disabled?: true
else
  config :indexer, Indexer.Fetcher.BlockReward.Supervisor, disabled?: false
end

config :indexer, Indexer.Fetcher.InternalTransaction.Supervisor,
  disabled?: System.get_env("INDEXER_DISABLE_INTERNAL_TRANSACTIONS_FETCHER", "false") == "true"

config :indexer, Indexer.Supervisor, enabled: System.get_env("DISABLE_INDEXER") != "true"

config :indexer, Indexer.Tracer,
  service: :indexer,
  adapter: SpandexDatadog.Adapter,
  trace_key: :blockscout

config :logger, :indexer,
  # keep synced with `config/config.exs`
  format: "$dateT$time $metadata[$level] $message\n",
  metadata:
    ~w(application fetcher request_id first_block_number last_block_number missing_block_range_count missing_block_count
       block_number step count error_count shrunk import_id transaction_id)a,
  metadata_filter: [application: :indexer]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
