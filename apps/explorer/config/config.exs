# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.
import Config

disable_indexer = System.get_env("DISABLE_INDEXER")
disable_webapp = System.get_env("DISABLE_WEBAPP")

# General application configuration
config :explorer,
  ecto_repos: [Explorer.Repo],
  coin: System.get_env("COIN") || "POA",
  token_functions_reader_max_retries: 3,
  allowed_evm_versions:
    System.get_env("ALLOWED_EVM_VERSIONS") ||
      "homestead,tangerineWhistle,spuriousDragon,byzantium,constantinople,petersburg,istanbul,berlin,london,default",
  include_uncles_in_average_block_time:
    if(System.get_env("UNCLES_IN_AVERAGE_BLOCK_TIME") == "true", do: true, else: false),
  healthy_blocks_period: System.get_env("HEALTHY_BLOCKS_PERIOD") || :timer.minutes(5),
  realtime_events_sender:
    if(disable_webapp != "true",
      do: Explorer.Chain.Events.SimpleSender,
      else: Explorer.Chain.Events.DBSender
    )

config :explorer, Explorer.Counters.AverageBlockTime,
  enabled: true,
  period: :timer.minutes(10)

config :explorer, Explorer.Chain.Events.Listener,
  enabled:
    if(disable_webapp == "true" && disable_indexer == "true",
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
  ttl_check_interval: if(disable_indexer == "true", do: :timer.seconds(1), else: false),
  global_ttl: if(disable_indexer == "true", do: :timer.seconds(5))

address_sum_global_ttl =
  "CACHE_ADDRESS_SUM_PERIOD"
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

cache_address_with_balances_update_interval = System.get_env("CACHE_ADDRESS_WITH_BALANCES_UPDATE_INTERVAL")

balances_update_interval =
  if cache_address_with_balances_update_interval do
    case Integer.parse(cache_address_with_balances_update_interval) do
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

config :explorer, Explorer.Counters.AddressTokenTransfersCounter,
  enabled: true,
  enable_consolidation: true

config :explorer, Explorer.Counters.BlockBurnedFeeCounter,
  enabled: true,
  enable_consolidation: true

config :explorer, Explorer.Counters.BlockPriorityFeeCounter,
  enabled: true,
  enable_consolidation: true

config :explorer, Explorer.Chain.Cache.GasUsage,
  enabled: System.get_env("CACHE_ENABLE_TOTAL_GAS_USAGE_COUNTER") == "true"

cache_bridge_market_cap_update_interval = System.get_env("CACHE_BRIDGE_MARKET_CAP_UPDATE_INTERVAL")

bridge_market_cap_update_interval =
  if cache_bridge_market_cap_update_interval do
    case Integer.parse(cache_bridge_market_cap_update_interval) do
      {integer, ""} -> integer
      _ -> nil
    end
  end

config :explorer, Explorer.Counters.Bridge,
  enabled: if(System.get_env("SUPPLY_MODULE") === "TokenBridge", do: true, else: false),
  enable_consolidation: System.get_env("DISABLE_BRIDGE_MARKET_CAP_UPDATER") !== "true",
  update_interval_in_seconds: bridge_market_cap_update_interval || 30 * 60,
  disable_lp_tokens_in_market_cap: System.get_env("DISABLE_LP_TOKENS_IN_MARKET_CAP") == "true"

config :explorer, Explorer.ExchangeRates,
  enabled: System.get_env("DISABLE_EXCHANGE_RATES") != "true",
  store: :ets,
  coingecko_coin_id: System.get_env("EXCHANGE_RATES_COINGECKO_COIN_ID"),
  coingecko_api_key: System.get_env("EXCHANGE_RATES_COINGECKO_API_KEY"),
  coinmarketcap_api_key: System.get_env("EXCHANGE_RATES_COINMARKETCAP_API_KEY")

exchange_rates_source =
  cond do
    System.get_env("EXCHANGE_RATES_SOURCE") == "token_bridge" -> Explorer.ExchangeRates.Source.TokenBridge
    System.get_env("EXCHANGE_RATES_SOURCE") == "coin_gecko" -> Explorer.ExchangeRates.Source.CoinGecko
    System.get_env("EXCHANGE_RATES_SOURCE") == "coin_market_cap" -> Explorer.ExchangeRates.Source.CoinMarketCap
    true -> Explorer.ExchangeRates.Source.CoinGecko
  end

config :explorer, Explorer.ExchangeRates.Source, source: exchange_rates_source

config :explorer, Explorer.KnownTokens, enabled: System.get_env("DISABLE_KNOWN_TOKENS") != "true", store: :ets

config :explorer, Explorer.Integrations.EctoLogger, query_time_ms_threshold: :timer.seconds(2)

config :explorer, Explorer.Market.History.Cataloger, enabled: disable_indexer != "true"

config :explorer, Explorer.Chain.Cache.MinMissingBlockNumber, enabled: System.get_env("DISABLE_WRITE_API") != "true"

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

  config :explorer, Explorer.Validator.MetadataProcessor, enabled: disable_indexer != "true"
else
  config :explorer, Explorer.Validator.MetadataProcessor, enabled: false
end

config :explorer, Explorer.Chain.Block.Reward,
  validators_contract_address: System.get_env("VALIDATORS_CONTRACT"),
  keys_manager_contract_address: System.get_env("KEYS_MANAGER_CONTRACT")

pos_staking_contract = System.get_env("POS_STAKING_CONTRACT")

if pos_staking_contract do
  config :explorer, Explorer.Staking.ContractState,
    enabled: true,
    staking_contract_address: pos_staking_contract,
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
  ttl_check_interval: if(disable_indexer == "true", do: :timer.seconds(1), else: false),
  global_ttl: if(disable_indexer == "true", do: :timer.seconds(5))

config :explorer, Explorer.Chain.Cache.Transactions,
  ttl_check_interval: if(disable_indexer == "true", do: :timer.seconds(1), else: false),
  global_ttl: if(disable_indexer == "true", do: :timer.seconds(5))

config :explorer, Explorer.Chain.Cache.Accounts,
  ttl_check_interval: if(disable_indexer == "true", do: :timer.seconds(1), else: false),
  global_ttl: if(disable_indexer == "true", do: :timer.seconds(5))

config :explorer, Explorer.Chain.Cache.Uncles,
  ttl_check_interval: if(disable_indexer == "true", do: :timer.seconds(1), else: false),
  global_ttl: if(disable_indexer == "true", do: :timer.seconds(5))

config :explorer, Explorer.ThirdPartyIntegrations.Sourcify,
  server_url: System.get_env("SOURCIFY_SERVER_URL") || "https://sourcify.dev/server",
  enabled: System.get_env("ENABLE_SOURCIFY_INTEGRATION") == "true",
  chain_id: System.get_env("CHAIN_ID"),
  repo_url: System.get_env("SOURCIFY_REPO_URL") || "https://repo.sourcify.dev/contracts"

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
