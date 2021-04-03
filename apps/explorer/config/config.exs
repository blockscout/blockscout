# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.
use Mix.Config

# General application configuration
config :explorer,
  ecto_repos: [Explorer.Repo],
  coin: System.get_env("COIN") || "LYX",
  coingecko_coin_id: System.get_env("COINGECKO_COIN_ID"),
  token_functions_reader_max_retries: 3,
  allowed_evm_versions:
    System.get_env("ALLOWED_EVM_VERSIONS") ||
      "homestead,tangerineWhistle,spuriousDragon,byzantium,constantinople,petersburg,istanbul,default",
  include_uncles_in_average_block_time:
    if(System.get_env("UNCLES_IN_AVERAGE_BLOCK_TIME") == "true", do: true, else: false),
  healthy_blocks_period: System.get_env("HEALTHY_BLOCKS_PERIOD") || :timer.minutes(5),
  realtime_events_sender:
    if(System.get_env("DISABLE_WEBAPP") != "true",
      do: Explorer.Chain.Events.SimpleSender,
      else: Explorer.Chain.Events.DBSender
    )

config :explorer, Explorer.Counters.AverageBlockTime,
  enabled: true,
  period: :timer.minutes(10)

config :explorer, Explorer.Chain.Events.Listener,
  enabled:
    if(System.get_env("DISABLE_WEBAPP") == nil && System.get_env("DISABLE_INDEXER") == nil,
      do: false,
      else: true
    )

config :explorer, Explorer.ChainSpec.GenesisData,
  enabled: true,
  chain_spec_path: System.get_env("CHAIN_SPEC_PATH"),
  emission_format: System.get_env("EMISSION_FORMAT", "DEFAULT"),
  rewards_contract_address: System.get_env("REWARDS_CONTRACT", "0xeca443e8e1ab29971a45a9c57a6a9875701698a5")

config :explorer, Explorer.Chain.Cache.BlockNumber,
  enabled: true,
  ttl_check_interval: if(System.get_env("DISABLE_INDEXER") == "true", do: :timer.seconds(1), else: false),
  global_ttl: if(System.get_env("DISABLE_INDEXER") == "true", do: :timer.seconds(5))

address_sum_global_ttl =
  "ADDRESS_SUM_CACHE_PERIOD"
  |> System.get_env("")
  |> Integer.parse()
  |> case do
    {integer, ""} -> :timer.seconds(integer)
    _ -> :timer.minutes(60)
  end

config :explorer, Explorer.Chain.Cache.AddressSum,
  enabled: true,
  ttl_check_interval: :timer.seconds(1),
  global_ttl: address_sum_global_ttl

config :explorer, Explorer.Chain.Cache.AddressSumMinusBurnt,
  enabled: true,
  ttl_check_interval: :timer.seconds(1),
  global_ttl: address_sum_global_ttl

balances_update_interval =
  if System.get_env("ADDRESS_WITH_BALANCES_UPDATE_INTERVAL") do
    case Integer.parse(System.get_env("ADDRESS_WITH_BALANCES_UPDATE_INTERVAL")) do
      {integer, ""} -> integer
      _ -> nil
    end
  end

config :explorer, Explorer.Counters.AddressesWithBalanceCounter,
  enabled: false,
  enable_consolidation: true,
  update_interval_in_seconds: balances_update_interval || 30 * 60

config :explorer, Explorer.Counters.AddressesCounter,
  enabled: true,
  enable_consolidation: true,
  update_interval_in_seconds: balances_update_interval || 30 * 60

config :explorer, Explorer.Counters.AddressTransactionsGasUsageCounter,
  enabled: true,
  enable_consolidation: true

config :explorer, Explorer.Counters.AddressTokenUsdSum,
  enabled: true,
  enable_consolidation: true

config :explorer, Explorer.Chain.Cache.TokenExchangeRate,
  enabled: true,
  enable_consolidation: true

config :explorer, Explorer.Counters.TokenHoldersCounter,
  enabled: true,
  enable_consolidation: true

config :explorer, Explorer.Counters.TokenTransfersCounter,
  enabled: true,
  enable_consolidation: true

config :explorer, Explorer.Counters.AddressTransactionsCounter,
  enabled: true,
  enable_consolidation: true

bridge_market_cap_update_interval =
  if System.get_env("BRIDGE_MARKET_CAP_UPDATE_INTERVAL") do
    case Integer.parse(System.get_env("BRIDGE_MARKET_CAP_UPDATE_INTERVAL")) do
      {integer, ""} -> integer
      _ -> nil
    end
  end

config :explorer, Explorer.Counters.Bridge,
  enabled: if(System.get_env("SUPPLY_MODULE") === "TokenBridge", do: true, else: false),
  enable_consolidation: System.get_env("DISABLE_BRIDGE_MARKET_CAP_UPDATER") !== "true",
  update_interval_in_seconds: bridge_market_cap_update_interval || 30 * 60,
  disable_lp_tokens_in_market_cap: System.get_env("DISABLE_LP_TOKENS_IN_MARKET_CAP") == "true"

config :explorer, Explorer.ExchangeRates, enabled: System.get_env("DISABLE_EXCHANGE_RATES") != "true", store: :ets

config :explorer, Explorer.KnownTokens, enabled: System.get_env("DISABLE_KNOWN_TOKENS") != "true", store: :ets

config :explorer, Explorer.Integrations.EctoLogger, query_time_ms_threshold: :timer.seconds(2)

config :explorer, Explorer.Market.History.Cataloger, enabled: System.get_env("DISABLE_INDEXER") != "true"

txs_stats_init_lag =
  System.get_env("TXS_HISTORIAN_INIT_LAG", "0")
  |> Integer.parse()
  |> elem(0)
  |> :timer.minutes()

txs_stats_days_to_compile_at_init =
  System.get_env("TXS_STATS_DAYS_TO_COMPILE_AT_INIT", "40")
  |> Integer.parse()
  |> elem(0)

config :explorer, Explorer.Chain.Transaction.History.Historian,
  enabled: System.get_env("ENABLE_TXS_STATS", "false") != "false",
  init_lag: txs_stats_init_lag,
  days_to_compile_at_init: txs_stats_days_to_compile_at_init

history_fetch_interval =
  case Integer.parse(System.get_env("HISTORY_FETCH_INTERVAL", "")) do
    {mins, ""} -> mins
    _ -> 60
  end
  |> :timer.minutes()

config :explorer, Explorer.History.Process, history_fetch_interval: history_fetch_interval

config :explorer, Explorer.Repo, migration_timestamps: [type: :utc_datetime_usec]

config :explorer, Explorer.Tracer,
  service: :explorer,
  adapter: SpandexDatadog.Adapter,
  trace_key: :blockscout

if System.get_env("METADATA_CONTRACT") && System.get_env("VALIDATORS_CONTRACT") do
  config :explorer, Explorer.Validator.MetadataRetriever,
    metadata_contract_address: System.get_env("METADATA_CONTRACT"),
    validators_contract_address: System.get_env("VALIDATORS_CONTRACT")

  config :explorer, Explorer.Validator.MetadataProcessor, enabled: System.get_env("DISABLE_INDEXER") != "true"
else
  config :explorer, Explorer.Validator.MetadataProcessor, enabled: false
end

config :explorer, Explorer.Chain.Block.Reward,
  validators_contract_address: System.get_env("VALIDATORS_CONTRACT"),
  keys_manager_contract_address: System.get_env("KEYS_MANAGER_CONTRACT")

if System.get_env("POS_STAKING_CONTRACT") do
  config :explorer, Explorer.Staking.ContractState,
    enabled: true,
    staking_contract_address: System.get_env("POS_STAKING_CONTRACT"),
    eth_subscribe_max_delay: System.get_env("POS_ETH_SUBSCRIBE_MAX_DELAY", "60"),
    eth_blocknumber_pull_interval: System.get_env("POS_ETH_BLOCKNUMBER_PULL_INTERVAL", "500")
else
  config :explorer, Explorer.Staking.ContractState, enabled: false
end

case System.get_env("SUPPLY_MODULE") do
  "TokenBridge" ->
    config :explorer, supply: Explorer.Chain.Supply.TokenBridge

  "rsk" ->
    config :explorer, supply: Explorer.Chain.Supply.RSK

  _ ->
    :ok
end

if System.get_env("SOURCE_MODULE") == "TokenBridge" do
  config :explorer, Explorer.ExchangeRates.Source, source: Explorer.ExchangeRates.Source.TokenBridge
end

config :explorer,
  solc_bin_api_url: "https://solc-bin.ethereum.org",
  checksum_function: System.get_env("CHECKSUM_FUNCTION") && String.to_atom(System.get_env("CHECKSUM_FUNCTION"))

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

config :explorer, Explorer.Chain.Cache.Blocks,
  ttl_check_interval: if(System.get_env("DISABLE_INDEXER") == "true", do: :timer.seconds(1), else: false),
  global_ttl: if(System.get_env("DISABLE_INDEXER") == "true", do: :timer.seconds(5))

config :explorer, Explorer.Chain.Cache.Transactions,
  ttl_check_interval: if(System.get_env("DISABLE_INDEXER") == "true", do: :timer.seconds(1), else: false),
  global_ttl: if(System.get_env("DISABLE_INDEXER") == "true", do: :timer.seconds(5))

config :explorer, Explorer.Chain.Cache.Accounts,
  ttl_check_interval: if(System.get_env("DISABLE_INDEXER") == "true", do: :timer.seconds(1), else: false),
  global_ttl: if(System.get_env("DISABLE_INDEXER") == "true", do: :timer.seconds(5))

config :explorer, Explorer.Chain.Cache.PendingTransactions,
  enabled:
    if(System.get_env("ETHEREUM_JSONRPC_VARIANT") == "besu",
      do: false,
      else: true
    ),
  ttl_check_interval: if(System.get_env("DISABLE_INDEXER") == "true", do: :timer.seconds(1), else: false),
  global_ttl: if(System.get_env("DISABLE_INDEXER") == "true", do: :timer.seconds(5))

config :explorer, Explorer.Chain.Cache.Uncles,
  ttl_check_interval: if(System.get_env("DISABLE_INDEXER") == "true", do: :timer.seconds(1), else: false),
  global_ttl: if(System.get_env("DISABLE_INDEXER") == "true", do: :timer.seconds(5))

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
