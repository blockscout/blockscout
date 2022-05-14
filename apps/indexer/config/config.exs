# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
import Config

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
  #QUAI adaptation for specific URLs defined at bottom of file
  ETHEREUM_JSONRPC_HTTP_URL: "",
  ETHEREUM_JSONRPC_WS_URL: "",
  ETHEREUM_JSONRPC_TRACE_URL: "",


  block_transformer: block_transformer,
  ecto_repos: [Explorer.Repo],
  metadata_updater_seconds_interval:
    String.to_integer(System.get_env("TOKEN_METADATA_UPDATE_INTERVAL") || "#{2 * 24 * 60 * 60}"),
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
  config :indexer, Indexer.Fetcher.BlockReward.Supervisor,
    disabled?: System.get_env("INDEXER_DISABLE_BLOCK_REWARD_FETCHER", "false") == "true"
end

config :indexer, Indexer.Fetcher.InternalTransaction.Supervisor,
  disabled?: System.get_env("INDEXER_DISABLE_INTERNAL_TRANSACTIONS_FETCHER", "false") == "true"

config :indexer, Indexer.Fetcher.CoinBalance.Supervisor,
  disabled?: System.get_env("INDEXER_DISABLE_ADDRESS_COIN_BALANCE_FETCHER", "false") == "true"

config :indexer, Indexer.Fetcher.TokenUpdater.Supervisor,
  disabled?: System.get_env("INDEXER_DISABLE_CATALOGED_TOKEN_UPDATER_FETCHER", "false") == "true"

config :indexer, Indexer.Fetcher.EmptyBlocksSanitizer.Supervisor,
  disabled?: System.get_env("INDEXER_DISABLE_EMPTY_BLOCK_SANITIZER", "false") == "true"

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


case System.get_env("QUAI_CHAIN") do
  "PRIME" ->
    Application.put_env(:indexer, :ETHEREUM_JSONRPC_HTTP_URL, "http://localhost:8546")
    Application.put_env(:indexer, :ETHEREUM_JSONRPC_WS_URL, "http://localhost:8547")
    Application.put_env(:indexer, :ETHEREUM_JSONRPC_TRACE_URL, "http://localhost:8546")

  "REGION1" ->
    Application.put_env(:indexer, :ETHEREUM_JSONRPC_HTTP_URL, "http://localhost:8578")
    Application.put_env(:indexer, :ETHEREUM_JSONRPC_WS_URL, "http://localhost:8579")
    Application.put_env(:indexer, :ETHEREUM_JSONRPC_TRACE_URL, "http://localhost:8578")

  "REGION2" ->
    Application.put_env(:indexer, :ETHEREUM_JSONRPC_HTTP_URL, "http://localhost:8580")
    Application.put_env(:indexer, :ETHEREUM_JSONRPC_WS_URL, "http://localhost:8581")
    Application.put_env(:indexer, :ETHEREUM_JSONRPC_TRACE_URL, "http://localhost:8580")

  "REGION3" ->
    Application.put_env(:indexer, :ETHEREUM_JSONRPC_HTTP_URL, "http://localhost:8582")
    Application.put_env(:indexer, :ETHEREUM_JSONRPC_WS_URL, "http://localhost:8583")
    Application.put_env(:indexer, :ETHEREUM_JSONRPC_TRACE_URL, "http://localhost:8582")

  "ZONE11" ->
    Application.put_env(:indexer, :ETHEREUM_JSONRPC_HTTP_URL, "http://localhost:8610")
    Application.put_env(:indexer, :ETHEREUM_JSONRPC_WS_URL, "http://localhost:8611")
    Application.put_env(:indexer, :ETHEREUM_JSONRPC_TRACE_URL, "http://localhost:8610")

  "ZONE12" ->
    Application.put_env(:indexer, :ETHEREUM_JSONRPC_HTTP_URL, "http://localhost:8542")
    Application.put_env(:indexer, :ETHEREUM_JSONRPC_WS_URL, "http://localhost:8543")
    Application.put_env(:indexer, :ETHEREUM_JSONRPC_TRACE_URL, "http://localhost:8542")

  "ZONE13" ->
    Application.put_env(:indexer, :ETHEREUM_JSONRPC_HTTP_URL, "http://localhost:8674")
    Application.put_env(:indexer, :ETHEREUM_JSONRPC_WS_URL, "http://localhost:8675")
    Application.put_env(:indexer, :ETHEREUM_JSONRPC_TRACE_URL, "http://localhost:8674")

  "ZONE21" ->
    Application.put_env(:indexer, :ETHEREUM_JSONRPC_HTTP_URL, "http://localhost:8512")
    Application.put_env(:indexer, :ETHEREUM_JSONRPC_WS_URL, "http://localhost:8513")
    Application.put_env(:indexer, :ETHEREUM_JSONRPC_TRACE_URL, "http://localhost:8512")

  "ZONE22" ->
    Application.put_env(:indexer, :ETHEREUM_JSONRPC_HTTP_URL, "http://localhost:8544")
    Application.put_env(:indexer, :ETHEREUM_JSONRPC_WS_URL, "http://localhost:8545")
    Application.put_env(:indexer, :ETHEREUM_JSONRPC_TRACE_URL, "http://localhost:8544")

  "ZONE23" ->
    Application.put_env(:indexer, :ETHEREUM_JSONRPC_HTTP_URL, "http://localhost:8576")
    Application.put_env(:indexer, :ETHEREUM_JSONRPC_WS_URL, "http://localhost:8577")
    Application.put_env(:indexer, :ETHEREUM_JSONRPC_TRACE_URL, "http://localhost:8576")

  "ZONE31" ->
    Application.put_env(:indexer, :ETHEREUM_JSONRPC_HTTP_URL, "http://localhost:8614")
    Application.put_env(:indexer, :ETHEREUM_JSONRPC_WS_URL, "http://localhost:8615")
    Application.put_env(:indexer, :ETHEREUM_JSONRPC_TRACE_URL, "http://localhost:8614")

  "ZONE32" ->
    Application.put_env(:indexer, :ETHEREUM_JSONRPC_HTTP_URL, "http://localhost:8646")
    Application.put_env(:indexer, :ETHEREUM_JSONRPC_WS_URL, "http://localhost:8647")
    Application.put_env(:indexer, :ETHEREUM_JSONRPC_TRACE_URL, "http://localhost:8646")

  "ZONE33" ->
    Application.put_env(:indexer, :ETHEREUM_JSONRPC_HTTP_URL, "http://localhost:8678")
    Application.put_env(:indexer, :ETHEREUM_JSONRPC_WS_URL, "http://localhost:8679")
    Application.put_env(:indexer, :ETHEREUM_JSONRPC_TRACE_URL, "http://localhost:8678")

  _ ->
    :ok
end




# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
