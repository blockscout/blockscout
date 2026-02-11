import Config

[__DIR__ | ~w(config_helper.exs)]
|> Path.join()
|> Code.eval_file()

config :logger,
  backends: ConfigHelper.logger_backends()

config :logger, :default_handler,
  formatter:
    (if config_env() == :prod do
       LoggerJSON.Formatters.Basic.new(metadata: ConfigHelper.logger_backend_metadata())
     else
       Logger.Formatter.new(
         format: "$dateT$time $metadata[$level] $message\n",
         metadata: ConfigHelper.logger_backend_metadata()
       )
     end)

config :logger, :api,
  format: "$dateT$time $metadata[$level] $message\n",
  metadata: ConfigHelper.logger_metadata(),
  metadata_filter: [application: :api]

config :logger, :api_v2,
  format: "$dateT$time $metadata[$level] $message\n",
  metadata: ConfigHelper.logger_metadata(),
  metadata_filter: [application: :api_v2]

microservice_multichain_search_url = ConfigHelper.parse_url_env_var("MICROSERVICE_MULTICHAIN_SEARCH_URL")
transactions_stats_enabled = ConfigHelper.parse_bool_env_var("TXS_STATS_ENABLED", "true")

######################
### BlockScout Web ###
######################

disable_api? = ConfigHelper.parse_bool_env_var("DISABLE_API")

config :block_scout_web,
  version: System.get_env("BLOCKSCOUT_VERSION"),
  release_link: System.get_env("RELEASE_LINK"),
  show_percentage: ConfigHelper.parse_bool_env_var("SHOW_ADDRESS_MARKETCAP_PERCENTAGE", "true"),
  checksum_address_hashes: ConfigHelper.parse_bool_env_var("CHECKSUM_ADDRESS_HASHES", "true"),
  other_networks: System.get_env("SUPPORTED_CHAINS"),
  webapp_url: ConfigHelper.parse_url_env_var("WEBAPP_URL"),
  api_url: ConfigHelper.parse_url_env_var("API_URL"),
  apps_menu: ConfigHelper.parse_bool_env_var("APPS_MENU"),
  apps: System.get_env("APPS") || System.get_env("EXTERNAL_APPS"),
  gas_price: System.get_env("GAS_PRICE"),
  dark_forest_addresses: System.get_env("CUSTOM_CONTRACT_ADDRESSES_DARK_FOREST"),
  dark_forest_addresses_v_0_5: System.get_env("CUSTOM_CONTRACT_ADDRESSES_DARK_FOREST_V_0_5"),
  circles_addresses: System.get_env("CUSTOM_CONTRACT_ADDRESSES_CIRCLES"),
  new_tags: System.get_env("NEW_TAGS"),
  chain_id: System.get_env("CHAIN_ID"),
  json_rpc: System.get_env("JSON_RPC"),
  disable_add_to_mm_button: ConfigHelper.parse_bool_env_var("DISABLE_ADD_TO_MM_BUTTON"),
  permanent_dark_mode_enabled: ConfigHelper.parse_bool_env_var("PERMANENT_DARK_MODE_ENABLED"),
  permanent_light_mode_enabled: ConfigHelper.parse_bool_env_var("PERMANENT_LIGHT_MODE_ENABLED"),
  display_token_icons: ConfigHelper.parse_bool_env_var("DISPLAY_TOKEN_ICONS"),
  hide_block_miner: ConfigHelper.parse_bool_env_var("HIDE_BLOCK_MINER"),
  hide_scam_addresses: ConfigHelper.parse_bool_env_var("HIDE_SCAM_ADDRESSES"),
  show_tenderly_link: ConfigHelper.parse_bool_env_var("SHOW_TENDERLY_LINK"),
  sensitive_endpoints_api_key: System.get_env("API_SENSITIVE_ENDPOINTS_KEY"),
  disable_api?: disable_api?

config :block_scout_web, :recaptcha,
  v2_client_key: System.get_env("RE_CAPTCHA_CLIENT_KEY"),
  v2_secret_key: System.get_env("RE_CAPTCHA_SECRET_KEY"),
  v3_client_key: System.get_env("RE_CAPTCHA_V3_CLIENT_KEY"),
  v3_secret_key: System.get_env("RE_CAPTCHA_V3_SECRET_KEY"),
  is_disabled: ConfigHelper.parse_bool_env_var("RE_CAPTCHA_DISABLED"),
  check_hostname?: ConfigHelper.parse_bool_env_var("RE_CAPTCHA_CHECK_HOSTNAME", "true"),
  score_threshold: ConfigHelper.parse_float_env_var("RE_CAPTCHA_SCORE_THRESHOLD", "0.5"),
  bypass_token: ConfigHelper.safe_get_env("RE_CAPTCHA_BYPASS_TOKEN", nil),
  scoped_bypass_tokens: [
    token_instance_refetch_metadata:
      ConfigHelper.safe_get_env("RE_CAPTCHA_TOKEN_INSTANCE_REFETCH_METADATA_SCOPED_BYPASS_TOKEN", nil)
  ]

network_path =
  "NETWORK_PATH"
  |> System.get_env("/")
  |> (&(if String.ends_with?(&1, "/") do
          String.trim_trailing(&1, "/")
        else
          &1
        end)).()

# Configures the endpoint
config :block_scout_web, BlockScoutWeb.Endpoint,
  server: true,
  url: [
    path: network_path,
    scheme: System.get_env("BLOCKSCOUT_PROTOCOL") || "http",
    host: System.get_env("BLOCKSCOUT_HOST") || "localhost"
  ],
  render_errors: [view: BlockScoutWeb.ErrorView, accepts: ~w(html json)],
  pubsub_server: BlockScoutWeb.PubSub

config :block_scout_web, BlockScoutWeb.HealthEndpoint,
  server: true,
  url: [
    path: network_path,
    scheme: System.get_env("BLOCKSCOUT_PROTOCOL") || "http",
    host: System.get_env("BLOCKSCOUT_HOST") || "localhost"
  ],
  render_errors: [view: BlockScoutWeb.ErrorView, accepts: ~w(html json)],
  pubsub_server: BlockScoutWeb.PubSub

config :block_scout_web, BlockScoutWeb.Chain,
  network: System.get_env("NETWORK"),
  subnetwork: System.get_env("SUBNETWORK"),
  network_icon: System.get_env("NETWORK_ICON"),
  logo: System.get_env("LOGO"),
  logo_text: System.get_env("LOGO_TEXT"),
  has_emission_funds: false,
  show_maintenance_alert: ConfigHelper.parse_bool_env_var("SHOW_MAINTENANCE_ALERT"),
  enable_testnet_label: ConfigHelper.parse_bool_env_var("SHOW_TESTNET_LABEL"),
  testnet_label_text: System.get_env("TESTNET_LABEL_TEXT", "Testnet")

config :block_scout_web, :footer,
  logo: System.get_env("FOOTER_LOGO"),
  chat_link: System.get_env("FOOTER_CHAT_LINK", "https://discord.gg/blockscout"),
  github_link: System.get_env("FOOTER_GITHUB_LINK", "https://github.com/blockscout/blockscout"),
  forum_link_enabled: ConfigHelper.parse_bool_env_var("FOOTER_FORUM_LINK_ENABLED"),
  forum_link: System.get_env("FOOTER_FORUM_LINK", "https://forum.poa.network/c/blockscout"),
  telegram_link_enabled: ConfigHelper.parse_bool_env_var("FOOTER_TELEGRAM_LINK_ENABLED"),
  telegram_link: System.get_env("FOOTER_TELEGRAM_LINK"),
  link_to_other_explorers: ConfigHelper.parse_bool_env_var("FOOTER_LINK_TO_OTHER_EXPLORERS"),
  other_explorers: System.get_env("FOOTER_OTHER_EXPLORERS", "")

config :block_scout_web, :contract,
  verification_max_libraries: ConfigHelper.parse_integer_env_var("CONTRACT_VERIFICATION_MAX_LIBRARIES", 10),
  max_length_to_show_string_without_trimming: System.get_env("CONTRACT_MAX_STRING_LENGTH_WITHOUT_TRIMMING", "2040"),
  disable_interaction: ConfigHelper.parse_bool_env_var("CONTRACT_DISABLE_INTERACTION"),
  certified_list: ConfigHelper.parse_list_env_var("CONTRACT_CERTIFIED_LIST", ""),
  partial_reverification_disabled: !ConfigHelper.parse_bool_env_var("CONTRACT_ENABLE_PARTIAL_REVERIFICATION")

default_global_api_rate_limit = 25
default_api_rate_limit_by_key = 10
api_rate_limit_redis_url = ConfigHelper.safe_get_env("API_RATE_LIMIT_HAMMER_REDIS_URL", nil)

config :block_scout_web, :api_rate_limit,
  disabled: ConfigHelper.parse_bool_env_var("API_RATE_LIMIT_DISABLED"),
  static_api_key_value: System.get_env("API_RATE_LIMIT_STATIC_API_KEY"),
  static_api_key: %{
    limit: ConfigHelper.parse_integer_env_var("API_RATE_LIMIT_BY_KEY", default_api_rate_limit_by_key),
    period: ConfigHelper.parse_time_env_var("API_RATE_LIMIT_BY_KEY_TIME_INTERVAL", "1s")
  },
  whitelisted_ip: %{
    limit: ConfigHelper.parse_integer_env_var("API_RATE_LIMIT_BY_WHITELISTED_IP", default_global_api_rate_limit),
    period: ConfigHelper.parse_time_env_var("API_RATE_LIMIT_BY_WHITELISTED_IP_TIME_INTERVAL", "1s")
  },
  ip: %{
    limit: ConfigHelper.parse_integer_env_var("API_RATE_LIMIT_BY_IP", 300),
    period: ConfigHelper.parse_time_env_var("API_RATE_LIMIT_BY_IP_TIME_INTERVAL", "1m")
  },
  temporary_token: %{
    limit: ConfigHelper.parse_integer_env_var("API_RATE_LIMIT_UI_V2_WITH_TOKEN", 5),
    period: ConfigHelper.parse_time_env_var("API_RATE_LIMIT_UI_V2_WITH_TOKEN_TIME_INTERVAL", "1s")
  },
  account_api_key: %{
    period: ConfigHelper.parse_time_env_var("API_RATE_LIMIT_BY_ACCOUNT_API_KEY_TIME_INTERVAL", "1s")
  },
  no_rate_limit_api_key_value: System.get_env("API_NO_RATE_LIMIT_API_KEY"),
  whitelisted_ips: System.get_env("API_RATE_LIMIT_WHITELISTED_IPS"),
  api_v2_token_ttl: ConfigHelper.parse_time_env_var("API_RATE_LIMIT_UI_V2_TOKEN_TTL", "30m"),
  eth_json_rpc_max_batch_size: ConfigHelper.parse_integer_env_var("ETH_JSON_RPC_MAX_BATCH_SIZE", 5),
  redis_url: if(api_rate_limit_redis_url == "", do: nil, else: api_rate_limit_redis_url),
  rate_limit_backend:
    if(api_rate_limit_redis_url == "",
      do: BlockScoutWeb.RateLimit.Hammer.ETS,
      else: BlockScoutWeb.RateLimit.Hammer.Redis
    ),
  config_url: ConfigHelper.parse_url_env_var("API_RATE_LIMIT_CONFIG_URL")

config :block_scout_web, :remote_ip,
  is_blockscout_behind_proxy: ConfigHelper.parse_bool_env_var("API_RATE_LIMIT_IS_BLOCKSCOUT_BEHIND_PROXY"),
  headers: ConfigHelper.parse_list_env_var("API_RATE_LIMIT_REMOTE_IP_HEADERS", "x-forwarded-for"),
  proxies: ConfigHelper.parse_list_env_var("API_RATE_LIMIT_REMOTE_IP_KNOWN_PROXIES", "")

default_graphql_rate_limit = 10

config :block_scout_web, Api.GraphQL,
  default_transaction_hash:
    System.get_env(
      "API_GRAPHQL_DEFAULT_TRANSACTION_HASH",
      "0x69e3923eef50eada197c3336d546936d0c994211492c9f947a24c02827568f9f"
    ),
  enabled: ConfigHelper.parse_bool_env_var("API_GRAPHQL_ENABLED", "true"),
  rate_limit_disabled?: ConfigHelper.parse_bool_env_var("API_GRAPHQL_RATE_LIMIT_DISABLED"),
  global_limit: ConfigHelper.parse_integer_env_var("API_GRAPHQL_RATE_LIMIT", default_graphql_rate_limit),
  limit_by_key: ConfigHelper.parse_integer_env_var("API_GRAPHQL_RATE_LIMIT_BY_KEY", default_graphql_rate_limit),
  time_interval_limit: ConfigHelper.parse_time_env_var("API_GRAPHQL_RATE_LIMIT_TIME_INTERVAL", "1s"),
  limit_by_ip: ConfigHelper.parse_integer_env_var("API_GRAPHQL_RATE_LIMIT_BY_IP", 500),
  time_interval_limit_by_ip: ConfigHelper.parse_time_env_var("API_GRAPHQL_RATE_LIMIT_BY_IP_TIME_INTERVAL", "1h"),
  static_api_key: System.get_env("API_GRAPHQL_RATE_LIMIT_STATIC_API_KEY")

# Configures History
price_chart_config =
  if ConfigHelper.parse_bool_env_var("SHOW_PRICE_CHART") do
    %{market: [:price, :market_cap]}
  else
    %{}
  end

price_chart_legend_enabled? =
  ConfigHelper.parse_bool_env_var("SHOW_PRICE_CHART") || ConfigHelper.parse_bool_env_var("SHOW_PRICE_CHART_LEGEND")

transaction_chart_config =
  if ConfigHelper.parse_bool_env_var("SHOW_TXS_CHART", "true") do
    %{transactions: [:transactions_per_day]}
  else
    %{}
  end

config :block_scout_web, :chart,
  chart_config: Map.merge(price_chart_config, transaction_chart_config),
  price_chart_legend_enabled?: price_chart_legend_enabled?

config :block_scout_web, BlockScoutWeb.Chain.Address.CoinBalance,
  coin_balance_history_days: ConfigHelper.parse_integer_env_var("COIN_BALANCE_HISTORY_DAYS", 10)

config :block_scout_web, BlockScoutWeb.API.V2, enabled: ConfigHelper.parse_bool_env_var("API_V2_ENABLED", "true")

config :block_scout_web, BlockScoutWeb.MicroserviceInterfaces.TransactionInterpretation,
  service_url: ConfigHelper.parse_url_env_var("MICROSERVICE_TRANSACTION_INTERPRETATION_URL"),
  enabled: ConfigHelper.parse_bool_env_var("MICROSERVICE_TRANSACTION_INTERPRETATION_ENABLED")

# Configures Ueberauth's Auth0 auth provider
config :ueberauth, Ueberauth.Strategy.Auth0.OAuth,
  domain: System.get_env("ACCOUNT_AUTH0_DOMAIN"),
  client_id: System.get_env("ACCOUNT_AUTH0_CLIENT_ID"),
  client_secret: System.get_env("ACCOUNT_AUTH0_CLIENT_SECRET"),
  auth0_application_id: ConfigHelper.safe_get_env("ACCOUNT_AUTH0_APPLICATION_ID", nil) |> String.replace(".", "")

# Configures Ueberauth local settings
config :ueberauth, Ueberauth, logout_url: "https://#{System.get_env("ACCOUNT_AUTH0_DOMAIN")}/v2/logout"

########################
### Ethereum JSONRPC ###
########################

trace_url_missing? =
  System.get_env("ETHEREUM_JSONRPC_TRACE_URL") in ["", nil] and
    System.get_env("ETHEREUM_JSONRPC_TRACE_URLS") in ["", nil]

config :ethereum_jsonrpc,
  rpc_transport: if(System.get_env("ETHEREUM_JSONRPC_TRANSPORT", "http") == "http", do: :http, else: :ipc),
  ipc_path: System.get_env("IPC_PATH"),
  disable_archive_balances?:
    trace_url_missing? or ConfigHelper.parse_bool_env_var("ETHEREUM_JSONRPC_DISABLE_ARCHIVE_BALANCES"),
  archive_balances_window: ConfigHelper.parse_integer_env_var("ETHEREUM_JSONRPC_ARCHIVE_BALANCES_WINDOW", 200)

config :ethereum_jsonrpc, EthereumJSONRPC.HTTP,
  headers:
    %{"Content-Type" => "application/json"}
    |> Map.merge(ConfigHelper.parse_json_env_var("ETHEREUM_JSONRPC_HTTP_HEADERS", "{}"))
    |> Map.to_list(),
  gzip_enabled?: ConfigHelper.parse_bool_env_var("ETHEREUM_JSONRPC_HTTP_GZIP_ENABLED", "false")

config :ethereum_jsonrpc, EthereumJSONRPC.Geth,
  block_traceable?: ConfigHelper.parse_bool_env_var("ETHEREUM_JSONRPC_GETH_TRACE_BY_BLOCK"),
  allow_empty_traces?: ConfigHelper.parse_bool_env_var("ETHEREUM_JSONRPC_GETH_ALLOW_EMPTY_TRACES"),
  debug_trace_timeout: System.get_env("ETHEREUM_JSONRPC_DEBUG_TRACE_TRANSACTION_TIMEOUT", "5s"),
  tracer: System.get_env("INDEXER_INTERNAL_TRANSACTIONS_TRACER_TYPE", "call_tracer")

config :ethereum_jsonrpc, EthereumJSONRPC.PendingTransaction,
  type: System.get_env("ETHEREUM_JSONRPC_PENDING_TRANSACTIONS_TYPE", "default")

config :ethereum_jsonrpc, EthereumJSONRPC.RequestCoordinator,
  wait_per_timeout: ConfigHelper.parse_time_env_var("ETHEREUM_JSONRPC_WAIT_PER_TIMEOUT", "20s")

config :ethereum_jsonrpc, EthereumJSONRPC.WebSocket.RetryWorker,
  retry_interval: ConfigHelper.parse_time_env_var("ETHEREUM_JSONRPC_WS_RETRY_INTERVAL", "1m")

config :ethereum_jsonrpc, EthereumJSONRPC.Utility.EndpointAvailabilityChecker, enabled: true

################
### Explorer ###
################

app_mode = ConfigHelper.mode()
disable_indexer? = app_mode == :api || ConfigHelper.parse_bool_env_var("DISABLE_INDEXER")

disable_exchange_rates? =
  if System.get_env("DISABLE_MARKET"),
    do: ConfigHelper.parse_bool_env_var("DISABLE_MARKET"),
    else: ConfigHelper.parse_bool_env_var("DISABLE_EXCHANGE_RATES")

coin = System.get_env("COIN") || "ETH"

config :explorer,
  mode: app_mode,
  ecto_repos: ConfigHelper.repos(),
  chain_type: ConfigHelper.chain_type(),
  chain_identity: ConfigHelper.chain_identity(),
  coin: coin,
  coin_name: System.get_env("COIN_NAME") || "ETH",
  allowed_solidity_evm_versions:
    System.get_env("CONTRACT_VERIFICATION_ALLOWED_SOLIDITY_EVM_VERSIONS") ||
      "homestead,tangerineWhistle,spuriousDragon,byzantium,constantinople,petersburg,istanbul,berlin,london,paris,shanghai,cancun,prague,osaka,default",
  allowed_vyper_evm_versions:
    System.get_env("CONTRACT_VERIFICATION_ALLOWED_VYPER_EVM_VERSIONS") ||
      "byzantium,constantinople,petersburg,istanbul,berlin,paris,shanghai,cancun,osaka,default",
  include_uncles_in_average_block_time: ConfigHelper.parse_bool_env_var("UNCLES_IN_AVERAGE_BLOCK_TIME"),
  realtime_events_sender:
    (case app_mode do
       :all -> Explorer.Chain.Events.SimpleSender
       separate_setup when separate_setup in [:indexer, :api] -> Explorer.Chain.Events.DBSender
     end),
  addresses_blacklist: System.get_env("ADDRESSES_BLACKLIST"),
  addresses_blacklist_key: System.get_env("ADDRESSES_BLACKLIST_KEY"),
  elasticity_multiplier: ConfigHelper.parse_integer_env_var("EIP_1559_ELASTICITY_MULTIPLIER", 2),
  base_fee_max_change_denominator: ConfigHelper.parse_integer_env_var("EIP_1559_BASE_FEE_MAX_CHANGE_DENOMINATOR", 8),
  base_fee_lower_bound: ConfigHelper.parse_integer_env_var("EIP_1559_BASE_FEE_LOWER_BOUND_WEI", 0),
  csv_export_limit: ConfigHelper.parse_integer_env_var("CSV_EXPORT_LIMIT", 10_000),
  shrink_internal_transactions_enabled: ConfigHelper.parse_bool_env_var("SHRINK_INTERNAL_TRANSACTIONS_ENABLED"),
  replica_max_lag: ConfigHelper.parse_time_env_var("REPLICA_MAX_LAG", "5m"),
  hackney_default_pool_size: ConfigHelper.parse_integer_env_var("HACKNEY_DEFAULT_POOL_SIZE", 1_000)

config :explorer, Explorer.Chain.Health.Monitor,
  check_interval: ConfigHelper.parse_time_env_var("HEALTH_MONITOR_CHECK_INTERVAL", "1m"),
  healthy_blocks_period: ConfigHelper.parse_time_env_var("HEALTH_MONITOR_BLOCKS_PERIOD", "5m"),
  healthy_batches_period: ConfigHelper.parse_time_env_var("HEALTH_MONITOR_BATCHES_PERIOD", "4h")

config :explorer, :proxy,
  caching_implementation_data_enabled: true,
  implementation_data_ttl_via_avg_block_time:
    ConfigHelper.parse_bool_env_var("CONTRACT_PROXY_IMPLEMENTATION_TTL_VIA_AVG_BLOCK_TIME", "true"),
  fallback_cached_implementation_data_ttl: :timer.seconds(4),
  implementation_data_fetching_timeout: :timer.seconds(2)

config :explorer, Explorer.Chain.Events.Listener, enabled: app_mode == :api

precompiled_config_base_dir =
  case config_env() do
    :prod -> "/app/"
    _ -> "./"
  end

precompiled_config_default_path =
  case ConfigHelper.chain_type() do
    :arbitrum -> "#{precompiled_config_base_dir}config/assets/precompiles-arbitrum.json"
    _ -> nil
  end

config :explorer, Explorer.ChainSpec.GenesisData,
  chain_spec_path: System.get_env("CHAIN_SPEC_PATH"),
  genesis_processing_delay: ConfigHelper.parse_time_env_var("CHAIN_SPEC_PROCESSING_DELAY", "15s"),
  emission_format: System.get_env("EMISSION_FORMAT", "DEFAULT"),
  rewards_contract_address: System.get_env("REWARDS_CONTRACT", "0xeca443e8e1ab29971a45a9c57a6a9875701698a5"),
  precompiled_config_path: System.get_env("PRECOMPILED_CONTRACTS_CONFIG_PATH", precompiled_config_default_path)

address_sum_global_ttl = ConfigHelper.parse_time_env_var("CACHE_ADDRESS_SUM_PERIOD", "1h")

config :explorer, Explorer.Chain.Cache.Counters.AddressesCoinBalanceSum, global_ttl: address_sum_global_ttl

config :explorer, Explorer.Chain.Cache.Counters.AddressesCoinBalanceSumMinusBurnt, global_ttl: address_sum_global_ttl

config :explorer, Explorer.Chain.Cache.Counters.GasUsageSum,
  global_ttl: ConfigHelper.parse_time_env_var("CACHE_TOTAL_GAS_USAGE_PERIOD", "2h"),
  enabled: ConfigHelper.parse_bool_env_var("CACHE_TOTAL_GAS_USAGE_COUNTER_ENABLED")

config :explorer, Explorer.Chain.Cache.Counters.BlocksCount,
  global_ttl: ConfigHelper.parse_time_env_var("CACHE_BLOCK_COUNT_PERIOD", "2h")

config :explorer, Explorer.Chain.Cache.Counters.AddressesCount,
  update_interval_in_milliseconds: ConfigHelper.parse_time_env_var("CACHE_ADDRESS_COUNT_PERIOD", "30m")

config :explorer, Explorer.Chain.Cache.Counters.TransactionsCount,
  global_ttl: ConfigHelper.parse_time_env_var("CACHE_TXS_COUNT_PERIOD", "2h")

config :explorer, Explorer.Chain.Cache.Counters.PendingBlockOperationCount,
  global_ttl: ConfigHelper.parse_time_env_var("CACHE_PENDING_OPERATIONS_COUNT_PERIOD", "5m")

config :explorer, Explorer.Chain.Cache.Counters.PendingTransactionOperationCount,
  global_ttl: ConfigHelper.parse_time_env_var("CACHE_PENDING_OPERATIONS_COUNT_PERIOD", "5m")

config :explorer, Explorer.Chain.Cache.GasPriceOracle,
  global_ttl: ConfigHelper.parse_time_env_var("GAS_PRICE_ORACLE_CACHE_PERIOD", "30s"),
  simple_transaction_gas: ConfigHelper.parse_integer_env_var("GAS_PRICE_ORACLE_SIMPLE_TRANSACTION_GAS", 21_000),
  num_of_blocks: ConfigHelper.parse_integer_env_var("GAS_PRICE_ORACLE_NUM_OF_BLOCKS", 200),
  safelow_percentile: ConfigHelper.parse_integer_env_var("GAS_PRICE_ORACLE_SAFELOW_PERCENTILE", 35),
  average_percentile: ConfigHelper.parse_integer_env_var("GAS_PRICE_ORACLE_AVERAGE_PERCENTILE", 60),
  fast_percentile: ConfigHelper.parse_integer_env_var("GAS_PRICE_ORACLE_FAST_PERCENTILE", 90),
  safelow_time_coefficient: ConfigHelper.parse_float_env_var("GAS_PRICE_ORACLE_SAFELOW_TIME_COEFFICIENT", 5),
  average_time_coefficient: ConfigHelper.parse_float_env_var("GAS_PRICE_ORACLE_AVERAGE_TIME_COEFFICIENT", 3),
  fast_time_coefficient: ConfigHelper.parse_float_env_var("GAS_PRICE_ORACLE_FAST_TIME_COEFFICIENT", 1)

config :explorer, Explorer.Chain.Cache.Counters.Rootstock.LockedBTCCount,
  enabled: System.get_env("ETHEREUM_JSONRPC_VARIANT") == "rsk",
  global_ttl: ConfigHelper.parse_time_env_var("ROOTSTOCK_LOCKED_BTC_CACHE_PERIOD", "10m"),
  locking_cap: ConfigHelper.parse_integer_env_var("ROOTSTOCK_LOCKING_CAP", 21_000_000)

config :explorer, Explorer.Chain.Cache.OptimismFinalizationPeriod, enabled: ConfigHelper.chain_type() == :optimism

config :explorer, Explorer.Chain.Cache.Counters.AddressTransactionsGasUsageSum,
  cache_period: ConfigHelper.parse_time_env_var("CACHE_ADDRESS_TRANSACTIONS_GAS_USAGE_COUNTER_PERIOD", "30m")

config :explorer, Explorer.Chain.Cache.Counters.TokenHoldersCount,
  cache_period: ConfigHelper.parse_time_env_var("CACHE_TOKEN_HOLDERS_COUNTER_PERIOD", "1h")

config :explorer, Explorer.Chain.Cache.Counters.TokenTransfersCount,
  cache_period: ConfigHelper.parse_time_env_var("CACHE_TOKEN_TRANSFERS_COUNTER_PERIOD", "1h")

config :explorer, Explorer.Chain.Cache.Counters.AverageBlockTime,
  enabled: true,
  period: :timer.minutes(10),
  cache_period: ConfigHelper.parse_time_env_var("CACHE_AVERAGE_BLOCK_PERIOD", "30m"),
  num_of_blocks: ConfigHelper.parse_integer_env_var("CACHE_AVERAGE_BLOCK_TIME_WINDOW", 100)

config :explorer, Explorer.Market.MarketHistoryCache,
  cache_period: ConfigHelper.parse_time_env_var("CACHE_MARKET_HISTORY_PERIOD", "1h")

config :explorer, Explorer.Chain.Cache.Counters.AddressTransactionsCount,
  cache_period: ConfigHelper.parse_time_env_var("CACHE_ADDRESS_TRANSACTIONS_COUNTER_PERIOD", "1h")

config :explorer, Explorer.Chain.Cache.Counters.AddressTokensUsdSum,
  cache_period: ConfigHelper.parse_time_env_var("CACHE_ADDRESS_TOKENS_USD_SUM_PERIOD", "1h")

config :explorer, Explorer.Chain.Cache.Counters.AddressTokenTransfersCount,
  cache_period: ConfigHelper.parse_time_env_var("CACHE_ADDRESS_TOKEN_TRANSFERS_COUNTER_PERIOD", "1h")

config :explorer, Explorer.Chain.Cache.Counters.Optimism.LastOutputRootSizeCount,
  enabled: ConfigHelper.chain_type() == :optimism,
  enable_consolidation: ConfigHelper.chain_type() == :optimism,
  cache_period: ConfigHelper.parse_time_env_var("CACHE_OPTIMISM_LAST_OUTPUT_ROOT_SIZE_COUNTER_PERIOD", "5m")

config :explorer, Explorer.Chain.Cache.Counters.Transactions24hCount,
  enabled: true,
  cache_period: ConfigHelper.parse_time_env_var("CACHE_TRANSACTIONS_24H_STATS_PERIOD", "1h"),
  enable_consolidation: true

config :explorer, Explorer.Chain.Cache.Counters.NewPendingTransactionsCount,
  enabled: true,
  cache_period: ConfigHelper.parse_time_env_var("CACHE_FRESH_PENDING_TRANSACTIONS_COUNTER_PERIOD", "5m"),
  enable_consolidation: true

config :explorer, Explorer.Market, enabled: !disable_exchange_rates?

config :explorer, Explorer.Market.Source,
  native_coin_source:
    ConfigHelper.market_source("MARKET_NATIVE_COIN_SOURCE") || ConfigHelper.market_source("EXCHANGE_RATES_SOURCE"),
  secondary_coin_source:
    ConfigHelper.market_source("MARKET_SECONDARY_COIN_SOURCE") ||
      ConfigHelper.market_source("EXCHANGE_RATES_SECONDARY_COIN_SOURCE"),
  tokens_source:
    ConfigHelper.market_source("MARKET_TOKENS_SOURCE") || ConfigHelper.market_source("TOKEN_EXCHANGE_RATES_SOURCE"),
  native_coin_history_source:
    ConfigHelper.market_source("MARKET_NATIVE_COIN_HISTORY_SOURCE") ||
      ConfigHelper.market_source("EXCHANGE_RATES_PRICE_SOURCE"),
  secondary_coin_history_source: ConfigHelper.market_source("MARKET_SECONDARY_COIN_HISTORY_SOURCE"),
  market_cap_history_source:
    ConfigHelper.market_source("MARKET_CAP_HISTORY_SOURCE") ||
      ConfigHelper.market_source("EXCHANGE_RATES_MARKET_CAP_SOURCE"),
  tvl_history_source:
    ConfigHelper.market_source("MARKET_TVL_HISTORY_SOURCE") || ConfigHelper.market_source("EXCHANGE_RATES_TVL_SOURCE")

config :explorer, Explorer.Market.Source.CoinGecko,
  platform: System.get_env("MARKET_COINGECKO_PLATFORM_ID") || System.get_env("EXCHANGE_RATES_COINGECKO_PLATFORM_ID"),
  base_url:
    ConfigHelper.parse_url_env_var("MARKET_COINGECKO_BASE_URL") ||
      ConfigHelper.parse_url_env_var("EXCHANGE_RATES_COINGECKO_BASE_URL", "https://api.coingecko.com/api/v3"),
  base_pro_url:
    ConfigHelper.parse_url_env_var("MARKET_COINGECKO_BASE_PRO_URL") ||
      ConfigHelper.parse_url_env_var("EXCHANGE_RATES_COINGECKO_BASE_PRO_URL", "https://pro-api.coingecko.com/api/v3"),
  api_key: System.get_env("MARKET_COINGECKO_API_KEY") || System.get_env("EXCHANGE_RATES_COINGECKO_API_KEY"),
  coin_id: System.get_env("MARKET_COINGECKO_COIN_ID") || System.get_env("EXCHANGE_RATES_COINGECKO_COIN_ID"),
  secondary_coin_id:
    System.get_env("MARKET_COINGECKO_SECONDARY_COIN_ID") || System.get_env("EXCHANGE_RATES_COINGECKO_SECONDARY_COIN_ID"),
  currency: "usd"

config :explorer, Explorer.Market.Source.CoinMarketCap,
  base_url:
    ConfigHelper.parse_url_env_var("MARKET_COINMARKETCAP_BASE_URL") ||
      ConfigHelper.parse_url_env_var("EXCHANGE_RATES_COINMARKETCAP_BASE_URL", "https://pro-api.coinmarketcap.com/v2"),
  api_key: System.get_env("MARKET_COINMARKETCAP_API_KEY") || System.get_env("EXCHANGE_RATES_COINMARKETCAP_API_KEY"),
  coin_id: System.get_env("MARKET_COINMARKETCAP_COIN_ID") || System.get_env("EXCHANGE_RATES_COINMARKETCAP_COIN_ID"),
  secondary_coin_id:
    System.get_env("MARKET_COINMARKETCAP_SECONDARY_COIN_ID") ||
      System.get_env("EXCHANGE_RATES_COINMARKETCAP_SECONDARY_COIN_ID"),
  currency_id: "2781"

config :explorer, Explorer.Market.Source.CryptoCompare,
  base_url: ConfigHelper.parse_url_env_var("MARKET_CRYPTOCOMPARE_BASE_URL", "https://min-api.cryptocompare.com"),
  coin_symbol: System.get_env("MARKET_CRYPTOCOMPARE_COIN_SYMBOL", coin),
  secondary_coin_symbol:
    System.get_env("MARKET_CRYPTOCOMPARE_SECONDARY_COIN_SYMBOL") ||
      System.get_env("EXCHANGE_RATES_CRYPTOCOMPARE_SECONDARY_COIN_SYMBOL"),
  currency: "USD"

config :explorer, Explorer.Market.Source.CryptoRank,
  platform:
    ConfigHelper.parse_integer_or_nil_env_var("MARKET_CRYPTORANK_PLATFORM_ID") ||
      ConfigHelper.parse_integer_or_nil_env_var("EXCHANGE_RATES_CRYPTORANK_PLATFORM_ID"),
  base_url:
    ConfigHelper.parse_url_env_var("MARKET_CRYPTORANK_BASE_URL") ||
      ConfigHelper.parse_url_env_var("EXCHANGE_RATES_CRYPTORANK_BASE_URL", "https://api.cryptorank.io/v1"),
  api_key: System.get_env("MARKET_CRYPTORANK_API_KEY") || System.get_env("EXCHANGE_RATES_CRYPTORANK_API_KEY"),
  coin_id:
    System.get_env("MARKET_CRYPTORANK_COIN_ID") ||
      ConfigHelper.parse_integer_or_nil_env_var("EXCHANGE_RATES_CRYPTORANK_COIN_ID"),
  secondary_coin_id:
    System.get_env("MARKET_CRYPTORANK_SECONDARY_COIN_ID") ||
      ConfigHelper.parse_integer_or_nil_env_var("EXCHANGE_RATES_CRYPTORANK_SECONDARY_COIN_ID"),
  currency: "USD"

config :explorer, Explorer.Market.Source.DefiLlama,
  coin_id: System.get_env("MARKET_DEFILLAMA_COIN_ID"),
  base_url: "https://api.llama.fi/v2"

config :explorer, Explorer.Market.Source.Mobula,
  platform: System.get_env("MARKET_MOBULA_PLATFORM_ID") || System.get_env("EXCHANGE_RATES_MOBULA_CHAIN_ID"),
  base_url:
    ConfigHelper.parse_url_env_var("MARKET_MOBULA_BASE_URL") ||
      ConfigHelper.parse_url_env_var("EXCHANGE_RATES_MOBULA_BASE_URL", "https://api.mobula.io/api/1"),
  api_key: System.get_env("MARKET_MOBULA_API_KEY") || System.get_env("EXCHANGE_RATES_MOBULA_API_KEY"),
  coin_id: System.get_env("MARKET_MOBULA_COIN_ID") || System.get_env("EXCHANGE_RATES_MOBULA_COIN_ID"),
  secondary_coin_id:
    System.get_env("MARKET_MOBULA_SECONDARY_COIN_ID") || System.get_env("EXCHANGE_RATES_MOBULA_SECONDARY_COIN_ID")

config :explorer, Explorer.Market.Source.DIA,
  blockchain: System.get_env("MARKET_DIA_BLOCKCHAIN"),
  base_url: ConfigHelper.parse_url_env_var("MARKET_DIA_BASE_URL", "https://api.diadata.org/v1"),
  coin_address_hash: System.get_env("MARKET_DIA_COIN_ADDRESS_HASH"),
  secondary_coin_address_hash: System.get_env("MARKET_DIA_SECONDARY_COIN_ADDRESS_HASH")

config :explorer, Explorer.Market.Fetcher.Coin,
  store: :ets,
  enabled: !disable_exchange_rates? && ConfigHelper.parse_bool_env_var("MARKET_COIN_FETCHER_ENABLED", "true"),
  enable_consolidation: true,
  cache_period: ConfigHelper.parse_time_env_var("MARKET_COIN_CACHE_PERIOD", "10m")

disable_token_exchange_rates? = ConfigHelper.parse_bool_env_var("DISABLE_TOKEN_EXCHANGE_RATE")
market_tokens_fetcher_enabled? = ConfigHelper.parse_bool_env_var("MARKET_TOKENS_FETCHER_ENABLED", "true")

config :explorer, Explorer.Market.Fetcher.Token,
  enabled: !disable_exchange_rates? && !disable_token_exchange_rates? && market_tokens_fetcher_enabled?,
  interval:
    ConfigHelper.parse_time_env_var(
      "MARKET_TOKENS_INTERVAL",
      ConfigHelper.safe_get_env("TOKEN_EXCHANGE_RATE_INTERVAL", "10s")
    ),
  refetch_interval:
    ConfigHelper.parse_time_env_var(
      "MARKET_TOKENS_REFETCH_INTERVAL",
      ConfigHelper.safe_get_env("TOKEN_EXCHANGE_RATE_REFETCH_INTERVAL", "1h")
    ),
  max_batch_size:
    ConfigHelper.parse_integer_env_var(
      "MARKET_TOKENS_MAX_BATCH_SIZE",
      ConfigHelper.parse_integer_env_var("TOKEN_EXCHANGE_RATE_MAX_BATCH_SIZE", 500)
    )

config :explorer, Explorer.Market.Fetcher.History,
  enabled: !disable_exchange_rates? && ConfigHelper.parse_bool_env_var("MARKET_HISTORY_FETCHER_ENABLED", "true"),
  history_fetch_interval: ConfigHelper.parse_time_env_var("MARKET_HISTORY_FETCH_INTERVAL", "1h"),
  first_fetch_day_count:
    ConfigHelper.parse_integer_env_var(
      "MARKET_HISTORY_FIRST_FETCH_DAY_COUNT",
      ConfigHelper.parse_integer_env_var("EXCHANGE_RATES_HISTORY_FIRST_FETCH_DAY_COUNT", 365)
    )

config :explorer, Explorer.Chain.Transaction,
  block_miner_gets_burnt_fees?: ConfigHelper.parse_bool_env_var("BLOCK_MINER_GETS_BURNT_FEES"),
  suave_bid_contracts: System.get_env("SUAVE_BID_CONTRACTS", ""),
  rootstock_remasc_address: System.get_env("ROOTSTOCK_REMASC_ADDRESS"),
  rootstock_bridge_address: System.get_env("ROOTSTOCK_BRIDGE_ADDRESS")

config :explorer, Explorer.Chain.Transaction.History.Historian,
  enabled: transactions_stats_enabled,
  init_lag_milliseconds: ConfigHelper.parse_time_env_var("TXS_HISTORIAN_INIT_LAG", "0"),
  days_to_compile_at_init: ConfigHelper.parse_integer_env_var("TXS_STATS_DAYS_TO_COMPILE_AT_INIT", 40)

if System.get_env("METADATA_CONTRACT") && System.get_env("VALIDATORS_CONTRACT") do
  config :explorer, Explorer.Validator.MetadataRetriever,
    metadata_contract_address: System.get_env("METADATA_CONTRACT"),
    validators_contract_address: System.get_env("VALIDATORS_CONTRACT")

  config :explorer, Explorer.Validator.MetadataProcessor, enabled: !disable_indexer?
else
  config :explorer, Explorer.Validator.MetadataProcessor, enabled: false
end

config :explorer, Explorer.Chain.Block.Reward,
  validators_contract_address: System.get_env("VALIDATORS_CONTRACT"),
  keys_manager_contract_address: System.get_env("KEYS_MANAGER_CONTRACT")

case System.get_env("SUPPLY_MODULE") do
  "rsk" ->
    config :explorer, supply: Explorer.Chain.Supply.RSK

  _ ->
    :ok
end

config :explorer, Explorer.Chain.Cache.BlockNumber,
  ttl_check_interval: ConfigHelper.cache_ttl_check_interval(disable_indexer?),
  global_ttl: ConfigHelper.cache_global_ttl(disable_indexer?)

config :explorer, Explorer.Chain.Cache.Blocks,
  ttl_check_interval: false,
  global_ttl: nil

config :explorer, Explorer.Chain.Cache.Transactions,
  ttl_check_interval: false,
  global_ttl: nil

config :explorer, Explorer.Chain.Cache.Accounts,
  ttl_check_interval: ConfigHelper.cache_ttl_check_interval(disable_indexer?),
  global_ttl: ConfigHelper.cache_global_ttl(disable_indexer?)

config :explorer, Explorer.Chain.Cache.Uncles,
  ttl_check_interval: false,
  global_ttl: nil

celo_l2_migration_block = ConfigHelper.parse_integer_or_nil_env_var("CELO_L2_MIGRATION_BLOCK")
celo_epoch_manager_contract_address = System.get_env("CELO_EPOCH_MANAGER_CONTRACT")

config :explorer, :celo,
  l2_migration_block: celo_l2_migration_block,
  epoch_manager_contract_address: celo_epoch_manager_contract_address,
  unreleased_treasury_contract_address: System.get_env("CELO_UNRELEASED_TREASURY_CONTRACT"),
  validators_contract_address: System.get_env("CELO_VALIDATORS_CONTRACT"),
  locked_gold_contract_address: System.get_env("CELO_LOCKED_GOLD_CONTRACT"),
  accounts_contract_address: System.get_env("CELO_ACCOUNTS_CONTRACT")

config :explorer, Explorer.Chain.Cache.CeloCoreContracts,
  contracts: ConfigHelper.parse_json_env_var("CELO_CORE_CONTRACTS")

config :explorer, Explorer.ThirdPartyIntegrations.Sourcify,
  server_url: ConfigHelper.parse_url_env_var("SOURCIFY_SERVER_URL", "https://sourcify.dev/server"),
  enabled: ConfigHelper.parse_bool_env_var("SOURCIFY_INTEGRATION_ENABLED"),
  chain_id: System.get_env("CHAIN_ID"),
  repo_url: ConfigHelper.parse_url_env_var("SOURCIFY_REPO_URL", "https://repo.sourcify.dev/contracts")

config :explorer, Explorer.ThirdPartyIntegrations.SolidityScan,
  platform_id: System.get_env("SOLIDITYSCAN_PLATFORM_ID", "16"),
  chain_id: System.get_env("SOLIDITYSCAN_CHAIN_ID"),
  api_key: System.get_env("SOLIDITYSCAN_API_TOKEN")

config :explorer, Explorer.ThirdPartyIntegrations.NovesFi,
  service_url: ConfigHelper.parse_url_env_var("NOVES_FI_BASE_API_URL", "https://blockscout.noves.fi"),
  chain_name: System.get_env("NOVES_FI_CHAIN_NAME"),
  api_key: System.get_env("NOVES_FI_API_TOKEN")

config :explorer, Explorer.ThirdPartyIntegrations.Xname,
  service_url: ConfigHelper.parse_url_env_var("XNAME_BASE_API_URL", "https://gateway.xname.app"),
  api_key: System.get_env("XNAME_API_TOKEN")

dynamic_env_id = System.get_env("ACCOUNT_DYNAMIC_ENV_ID")

config :explorer, Explorer.ThirdPartyIntegrations.Dynamic,
  enabled: !is_nil(dynamic_env_id),
  env_id: dynamic_env_id,
  url: "https://app.dynamic.xyz/api/v0/sdk/#{dynamic_env_id}/.well-known/jwks"

config :explorer, Explorer.ThirdPartyIntegrations.Dynamic.Strategy, enabled: !is_nil(dynamic_env_id)

enabled? = ConfigHelper.parse_bool_env_var("MICROSERVICE_SC_VERIFIER_ENABLED", "true")
# or "eth_bytecode_db"
type = System.get_env("MICROSERVICE_SC_VERIFIER_TYPE", "sc_verifier")

config :explorer, Explorer.SmartContract.RustVerifierInterfaceBehaviour,
  service_url:
    ConfigHelper.parse_url_env_var("MICROSERVICE_SC_VERIFIER_URL", "https://eth-bytecode-db.services.blockscout.com"),
  enabled: enabled?,
  type: type,
  eth_bytecode_db?: enabled? && type == "eth_bytecode_db",
  api_key: System.get_env("MICROSERVICE_SC_VERIFIER_API_KEY")

config :explorer, Explorer.Visualize.Sol2uml,
  service_url: ConfigHelper.parse_url_env_var("MICROSERVICE_VISUALIZE_SOL2UML_URL"),
  enabled: ConfigHelper.parse_bool_env_var("MICROSERVICE_VISUALIZE_SOL2UML_ENABLED")

config :explorer, Explorer.SmartContract.SigProviderInterface,
  service_url: ConfigHelper.parse_url_env_var("MICROSERVICE_SIG_PROVIDER_URL"),
  enabled: ConfigHelper.parse_bool_env_var("MICROSERVICE_SIG_PROVIDER_ENABLED")

config :explorer, Explorer.MicroserviceInterfaces.BENS,
  service_url: ConfigHelper.parse_url_env_var("MICROSERVICE_BENS_URL"),
  enabled: ConfigHelper.parse_bool_env_var("MICROSERVICE_BENS_ENABLED")

config :explorer, Explorer.MicroserviceInterfaces.AccountAbstraction,
  service_url: ConfigHelper.parse_url_env_var("MICROSERVICE_ACCOUNT_ABSTRACTION_URL"),
  enabled: ConfigHelper.parse_bool_env_var("MICROSERVICE_ACCOUNT_ABSTRACTION_ENABLED")

config :explorer, Explorer.MicroserviceInterfaces.Metadata,
  service_url: ConfigHelper.parse_url_env_var("MICROSERVICE_METADATA_URL"),
  enabled: ConfigHelper.parse_bool_env_var("MICROSERVICE_METADATA_ENABLED"),
  proxy_requests_timeout: ConfigHelper.parse_time_env_var("MICROSERVICE_METADATA_PROXY_REQUESTS_TIMEOUT", "30s")

config :explorer, Explorer.SmartContract.StylusVerifierInterface,
  service_url: ConfigHelper.parse_url_env_var("MICROSERVICE_STYLUS_VERIFIER_URL")

config :explorer, Explorer.MicroserviceInterfaces.MultichainSearch,
  api_key: System.get_env("MICROSERVICE_MULTICHAIN_SEARCH_API_KEY"),
  service_url: microservice_multichain_search_url,
  addresses_chunk_size:
    ConfigHelper.parse_integer_env_var("MICROSERVICE_MULTICHAIN_SEARCH_ADDRESSES_CHUNK_SIZE", 7_000),
  token_info_chunk_size:
    ConfigHelper.parse_integer_env_var("MICROSERVICE_MULTICHAIN_SEARCH_TOKEN_INFO_CHUNK_SIZE", 1_000),
  counters_chunk_size: ConfigHelper.parse_integer_env_var("MICROSERVICE_MULTICHAIN_SEARCH_COUNTERS_CHUNK_SIZE", 1_000)

config :explorer, Explorer.MicroserviceInterfaces.TACOperationLifecycle,
  enabled: ConfigHelper.parse_bool_env_var("MICROSERVICE_TAC_OPERATION_LIFECYCLE_ENABLED", "true"),
  service_url: ConfigHelper.parse_url_env_var("MICROSERVICE_TAC_OPERATION_LIFECYCLE_URL")

audit_reports_table_url = System.get_env("CONTRACT_AUDIT_REPORTS_AIRTABLE_URL")
audit_reports_api_key = System.get_env("CONTRACT_AUDIT_REPORTS_AIRTABLE_API_KEY")

config :explorer, :air_table_audit_reports,
  table_url: audit_reports_table_url,
  api_key: audit_reports_api_key,
  enabled: (audit_reports_table_url && audit_reports_api_key && true) || false

config :explorer, Explorer.Mailer,
  adapter: Bamboo.SendGridAdapter,
  api_key: System.get_env("ACCOUNT_SENDGRID_API_KEY")

config :explorer, Explorer.Account,
  enabled: ConfigHelper.parse_bool_env_var("ACCOUNT_ENABLED"),
  sendgrid: [
    sender: System.get_env("ACCOUNT_SENDGRID_SENDER"),
    template: System.get_env("ACCOUNT_SENDGRID_TEMPLATE")
  ],
  verification_email_resend_interval:
    ConfigHelper.parse_time_env_var("ACCOUNT_VERIFICATION_EMAIL_RESEND_INTERVAL", "5m"),
  otp_resend_interval: ConfigHelper.parse_time_env_var("ACCOUNT_OTP_RESEND_INTERVAL", "1m"),
  private_tags_limit: ConfigHelper.parse_integer_env_var("ACCOUNT_PRIVATE_TAGS_LIMIT", 2_000),
  watchlist_addresses_limit: ConfigHelper.parse_integer_env_var("ACCOUNT_WATCHLIST_ADDRESSES_LIMIT", 15),
  notifications_limit_for_30_days:
    ConfigHelper.parse_integer_env_var("ACCOUNT_WATCHLIST_NOTIFICATIONS_LIMIT_FOR_30_DAYS", 1_000),
  siwe_message: System.get_env("ACCOUNT_SIWE_MESSAGE", "Sign in to Blockscout Account V2")

config :explorer, Explorer.Chain.Cache.MinMissingBlockNumber,
  enabled: !disable_indexer?,
  batch_size: ConfigHelper.parse_integer_env_var("MIN_MISSING_BLOCK_NUMBER_BATCH_SIZE", 100_000)

config :explorer, :spandex,
  batch_size: ConfigHelper.parse_integer_env_var("SPANDEX_BATCH_SIZE", 100),
  sync_threshold: ConfigHelper.parse_integer_env_var("SPANDEX_SYNC_THRESHOLD", 100)

config :explorer, :datadog, port: ConfigHelper.parse_integer_env_var("DATADOG_PORT", 8126)

config :explorer, Explorer.Chain.Cache.TransactionActionTokensData,
  max_cache_size: ConfigHelper.parse_integer_env_var("INDEXER_TX_ACTIONS_MAX_TOKEN_CACHE_SIZE", 100_000)

config :explorer, Explorer.Chain.Fetcher.LookUpSmartContractSourcesOnDemand,
  fetch_interval: ConfigHelper.parse_time_env_var("MICROSERVICE_ETH_BYTECODE_DB_INTERVAL_BETWEEN_LOOKUPS", "10m"),
  max_concurrency: ConfigHelper.parse_integer_env_var("MICROSERVICE_ETH_BYTECODE_DB_MAX_LOOKUPS_CONCURRENCY", 10)

config :explorer, Explorer.Chain.Cache.Counters.AddressTabsElementsCount,
  ttl: ConfigHelper.parse_time_env_var("ADDRESSES_TABS_COUNTERS_TTL", "10m")

config :explorer, Explorer.TokenInstanceOwnerAddressMigration,
  concurrency: ConfigHelper.parse_integer_env_var("MIGRATION_TOKEN_INSTANCE_OWNER_CONCURRENCY", 5),
  batch_size: ConfigHelper.parse_integer_env_var("MIGRATION_TOKEN_INSTANCE_OWNER_BATCH_SIZE", 50),
  enabled: ConfigHelper.parse_bool_env_var("MIGRATION_TOKEN_INSTANCE_OWNER_ENABLED")

config :explorer, Explorer.Migrator.TransactionsDenormalization,
  batch_size: ConfigHelper.parse_integer_env_var("MIGRATION_TRANSACTIONS_TABLE_DENORMALIZATION_BATCH_SIZE", 500),
  concurrency: ConfigHelper.parse_integer_env_var("MIGRATION_TRANSACTIONS_TABLE_DENORMALIZATION_CONCURRENCY", 10)

config :explorer, Explorer.Migrator.TokenTransferTokenType,
  batch_size: ConfigHelper.parse_integer_env_var("MIGRATION_TOKEN_TRANSFER_TOKEN_TYPE_BATCH_SIZE", 100),
  concurrency: ConfigHelper.parse_integer_env_var("MIGRATION_TOKEN_TRANSFER_TOKEN_TYPE_CONCURRENCY", 1)

config :explorer, Explorer.Migrator.SanitizeIncorrectNFTTokenTransfers,
  batch_size: ConfigHelper.parse_integer_env_var("MIGRATION_SANITIZE_INCORRECT_NFT_BATCH_SIZE", 100),
  concurrency: ConfigHelper.parse_integer_env_var("MIGRATION_SANITIZE_INCORRECT_NFT_CONCURRENCY", 1),
  timeout: ConfigHelper.parse_time_env_var("MIGRATION_SANITIZE_INCORRECT_NFT_TIMEOUT", "0s")

config :explorer, Explorer.Migrator.SanitizeIncorrectWETHTokenTransfers,
  batch_size: ConfigHelper.parse_integer_env_var("MIGRATION_SANITIZE_INCORRECT_WETH_BATCH_SIZE", 100),
  concurrency: ConfigHelper.parse_integer_env_var("MIGRATION_SANITIZE_INCORRECT_WETH_CONCURRENCY", 1),
  timeout: ConfigHelper.parse_time_env_var("MIGRATION_SANITIZE_INCORRECT_WETH_TIMEOUT", "0s")

config :explorer, Explorer.Migrator.ReindexInternalTransactionsWithIncompatibleStatus,
  batch_size: ConfigHelper.parse_integer_env_var("MIGRATION_REINDEX_INTERNAL_TRANSACTIONS_STATUS_BATCH_SIZE", 100),
  concurrency: ConfigHelper.parse_integer_env_var("MIGRATION_REINDEX_INTERNAL_TRANSACTIONS_STATUS_CONCURRENCY", 1),
  timeout: ConfigHelper.parse_time_env_var("MIGRATION_REINDEX_INTERNAL_TRANSACTIONS_STATUS_TIMEOUT", "0s")

config :explorer, Explorer.Migrator.ReindexDuplicatedInternalTransactions,
  batch_size: ConfigHelper.parse_integer_env_var("MIGRATION_REINDEX_DUPLICATED_INTERNAL_TRANSACTIONS_BATCH_SIZE", 100),
  concurrency: ConfigHelper.parse_integer_env_var("MIGRATION_REINDEX_DUPLICATED_INTERNAL_TRANSACTIONS_CONCURRENCY", 1),
  timeout: ConfigHelper.parse_time_env_var("MIGRATION_REINDEX_DUPLICATED_INTERNAL_TRANSACTIONS_TIMEOUT", "0s")

config :explorer, Explorer.Migrator.ReindexBlocksWithMissingTransactions,
  batch_size: ConfigHelper.parse_integer_env_var("MIGRATION_REINDEX_BLOCKS_WITH_MISSING_TRANSACTIONS_BATCH_SIZE", 10),
  concurrency: ConfigHelper.parse_integer_env_var("MIGRATION_REINDEX_BLOCKS_WITH_MISSING_TRANSACTIONS_CONCURRENCY", 1),
  timeout: ConfigHelper.parse_time_env_var("MIGRATION_REINDEX_BLOCKS_WITH_MISSING_TRANSACTIONS_TIMEOUT", "0s"),
  enabled: ConfigHelper.parse_bool_env_var("MIGRATION_REINDEX_BLOCKS_WITH_MISSING_TRANSACTIONS_ENABLED", "false")

config :explorer, Explorer.Migrator.RestoreOmittedWETHTransfers,
  concurrency: ConfigHelper.parse_integer_env_var("MIGRATION_RESTORE_OMITTED_WETH_TOKEN_TRANSFERS_CONCURRENCY", 5),
  batch_size: ConfigHelper.parse_integer_env_var("MIGRATION_RESTORE_OMITTED_WETH_TOKEN_TRANSFERS_BATCH_SIZE", 50),
  timeout: ConfigHelper.parse_time_env_var("MIGRATION_RESTORE_OMITTED_WETH_TOKEN_TRANSFERS_TIMEOUT", "250ms")

config :explorer, Explorer.Migrator.SanitizeDuplicatedLogIndexLogs,
  concurrency: ConfigHelper.parse_integer_env_var("MIGRATION_SANITIZE_DUPLICATED_LOG_INDEX_LOGS_CONCURRENCY", 10),
  batch_size: ConfigHelper.parse_integer_env_var("MIGRATION_SANITIZE_DUPLICATED_LOG_INDEX_LOGS_BATCH_SIZE", 500)

config :explorer, Explorer.Migrator.RefetchContractCodes,
  concurrency: ConfigHelper.parse_integer_env_var("MIGRATION_REFETCH_CONTRACT_CODES_CONCURRENCY", 5),
  batch_size: ConfigHelper.parse_integer_env_var("MIGRATION_REFETCH_CONTRACT_CODES_BATCH_SIZE", 100)

config :explorer, Explorer.Migrator.BackfillMultichainSearchDB,
  concurrency: 1,
  batch_size: ConfigHelper.parse_integer_env_var("MIGRATION_BACKFILL_MULTICHAIN_SEARCH_BATCH_SIZE", 10)

config :explorer, Explorer.Migrator.HeavyDbIndexOperation,
  check_interval: ConfigHelper.parse_time_env_var("MIGRATION_HEAVY_INDEX_OPERATIONS_CHECK_INTERVAL", "10m")

config :explorer, Explorer.Migrator.SanitizeVerifiedAddresses,
  enabled: !ConfigHelper.parse_bool_env_var("MIGRATION_SANITIZE_VERIFIED_ADDRESSES_DISABLED"),
  batch_size: ConfigHelper.parse_integer_env_var("MIGRATION_SANITIZE_VERIFIED_ADDRESSES_BATCH_SIZE", 500),
  concurrency: ConfigHelper.parse_integer_env_var("MIGRATION_SANITIZE_VERIFIED_ADDRESSES_CONCURRENCY", 1),
  timeout: ConfigHelper.parse_time_env_var("MIGRATION_SANITIZE_VERIFIED_ADDRESSES_TIMEOUT", "0s")

config :explorer, Explorer.Migrator.SanitizeEmptyContractCodeAddresses,
  batch_size: ConfigHelper.parse_integer_env_var("MIGRATION_SANITIZE_EMPTY_CONTRACT_CODE_ADDRESSES_BATCH_SIZE", 500),
  concurrency: ConfigHelper.parse_integer_env_var("MIGRATION_SANITIZE_EMPTY_CONTRACT_CODE_ADDRESSES_CONCURRENCY", 1)

config :explorer, Explorer.Migrator.ArbitrumDaRecordsNormalization,
  enabled: ConfigHelper.chain_type() == :arbitrum,
  batch_size: ConfigHelper.parse_integer_env_var("MIGRATION_ARBITRUM_DA_RECORDS_NORMALIZATION_BATCH_SIZE", 500),
  concurrency: ConfigHelper.parse_integer_env_var("MIGRATION_ARBITRUM_DA_RECORDS_NORMALIZATION_CONCURRENCY", 1)

config :explorer, Explorer.Migrator.HeavyDbIndexOperation.CreateArbitrumBatchL2BlocksUnconfirmedBlocksIndex,
  enabled: ConfigHelper.chain_type() == :arbitrum

config :explorer, Explorer.Migrator.HeavyDbIndexOperation.CreateTransactionsOperatorFeeConstantIndex,
  enabled: ConfigHelper.chain_type() == :optimism

config :explorer, Explorer.Migrator.FilecoinPendingAddressOperations,
  enabled: ConfigHelper.chain_type() == :filecoin,
  batch_size: ConfigHelper.parse_integer_env_var("MIGRATION_FILECOIN_PENDING_ADDRESS_OPERATIONS_BATCH_SIZE", 100),
  concurrency: ConfigHelper.parse_integer_env_var("MIGRATION_FILECOIN_PENDING_ADDRESS_OPERATIONS_CONCURRENCY", 1)

config :explorer, Explorer.Migrator.CeloAccounts, enabled: ConfigHelper.chain_identity() == {:optimism, :celo}

config :explorer, Explorer.Migrator.EmptyInternalTransactionsData,
  batch_size: ConfigHelper.parse_integer_env_var("MIGRATION_EMPTY_INTERNAL_TRANSACTIONS_DATA_BATCH_SIZE", 1000),
  concurrency: ConfigHelper.parse_integer_env_var("MIGRATION_EMPTY_INTERNAL_TRANSACTIONS_DATA_CONCURRENCY", 1),
  timeout: ConfigHelper.parse_time_env_var("MIGRATION_EMPTY_INTERNAL_TRANSACTIONS_DATA_TIMEOUT", "0s")

config :explorer, Explorer.Migrator.CeloAggregatedElectionRewards,
  enabled: ConfigHelper.chain_identity() == {:optimism, :celo}

config :explorer, Explorer.Migrator.CeloL2Epochs,
  enabled:
    ConfigHelper.chain_identity() == {:optimism, :celo} &&
      !is_nil(celo_l2_migration_block) &&
      !is_nil(celo_epoch_manager_contract_address)

config :explorer, Explorer.Chain.Cache.CeloEpochs, enabled: ConfigHelper.chain_identity() == {:optimism, :celo}

config :explorer, Explorer.Migrator.ShrinkInternalTransactions,
  enabled: ConfigHelper.parse_bool_env_var("SHRINK_INTERNAL_TRANSACTIONS_ENABLED"),
  batch_size: ConfigHelper.parse_integer_env_var("MIGRATION_SHRINK_INTERNAL_TRANSACTIONS_BATCH_SIZE", 100),
  concurrency: ConfigHelper.parse_integer_env_var("MIGRATION_SHRINK_INTERNAL_TRANSACTIONS_CONCURRENCY", 10)

config :explorer, Explorer.Migrator.SmartContractLanguage,
  enabled: !ConfigHelper.parse_bool_env_var("MIGRATION_SMART_CONTRACT_LANGUAGE_DISABLED"),
  batch_size: ConfigHelper.parse_integer_env_var("MIGRATION_SMART_CONTRACT_LANGUAGE_BATCH_SIZE", 100),
  concurrency: ConfigHelper.parse_integer_env_var("MIGRATION_SMART_CONTRACT_LANGUAGE_CONCURRENCY", 1)

config :explorer, Explorer.Migrator.BackfillMetadataURL,
  enabled: !ConfigHelper.parse_bool_env_var("MIGRATION_BACKFILL_METADATA_URL_DISABLED"),
  batch_size: ConfigHelper.parse_integer_env_var("MIGRATION_BACKFILL_METADATA_URL_BATCH_SIZE", 100),
  concurrency: ConfigHelper.parse_integer_env_var("MIGRATION_BACKFILL_METADATA_URL_CONCURRENCY", 5)

config :explorer, Explorer.Migrator.MergeAdjacentMissingBlockRanges,
  batch_size: ConfigHelper.parse_integer_env_var("MIGRATION_MERGE_ADJACENT_MISSING_BLOCK_RANGES_BATCH_SIZE", 100)

config :explorer, Explorer.Migrator.DeleteZeroValueInternalTransactions,
  enabled: ConfigHelper.parse_bool_env_var("MIGRATION_DELETE_ZERO_VALUE_INTERNAL_TRANSACTIONS_ENABLED", "false"),
  batch_size: ConfigHelper.parse_integer_env_var("MIGRATION_DELETE_ZERO_VALUE_INTERNAL_TRANSACTIONS_BATCH_SIZE", 100),
  storage_period:
    ConfigHelper.parse_time_env_var("MIGRATION_DELETE_ZERO_VALUE_INTERNAL_TRANSACTIONS_STORAGE_PERIOD", "30d"),
  check_interval:
    ConfigHelper.parse_time_env_var("MIGRATION_DELETE_ZERO_VALUE_INTERNAL_TRANSACTIONS_CHECK_INTERVAL", "1m")

config :explorer, Explorer.Chain.BridgedToken,
  eth_omni_bridge_mediator: System.get_env("BRIDGED_TOKENS_ETH_OMNI_BRIDGE_MEDIATOR"),
  bsc_omni_bridge_mediator: System.get_env("BRIDGED_TOKENS_BSC_OMNI_BRIDGE_MEDIATOR"),
  poa_omni_bridge_mediator: System.get_env("BRIDGED_TOKENS_POA_OMNI_BRIDGE_MEDIATOR"),
  amb_bridge_mediators: System.get_env("BRIDGED_TOKENS_AMB_BRIDGE_MEDIATORS"),
  foreign_json_rpc: System.get_env("BRIDGED_TOKENS_FOREIGN_JSON_RPC", "")

config :explorer, Explorer.Utility.MissingBalanceOfToken,
  window_size: ConfigHelper.parse_integer_env_var("MISSING_BALANCE_OF_TOKENS_WINDOW_SIZE", 100)

config :explorer, Explorer.Chain.TokenTransfer,
  whitelisted_weth_contracts: ConfigHelper.parse_list_env_var("WHITELISTED_WETH_CONTRACTS", ""),
  weth_token_transfers_filtering_enabled: ConfigHelper.parse_bool_env_var("WETH_TOKEN_TRANSFERS_FILTERING_ENABLED")

config :explorer, Explorer.Chain.Metrics.PublicMetrics,
  enabled: ConfigHelper.parse_bool_env_var("PUBLIC_METRICS_ENABLED", "false"),
  update_period_hours: ConfigHelper.parse_integer_env_var("PUBLIC_METRICS_UPDATE_PERIOD_HOURS", 24)

config :explorer, Explorer.Chain.Filecoin.NativeAddress,
  network_prefix: ConfigHelper.parse_catalog_value("FILECOIN_NETWORK_PREFIX", ["f", "t"], true, "f")

config :explorer, Explorer.Chain.Blackfort.Validator, api_url: System.get_env("BLACKFORT_VALIDATOR_API_URL")

addresses_blacklist_url = ConfigHelper.parse_url_env_var("ADDRESSES_BLACKLIST_URL")

config :explorer, Explorer.Chain.Fetcher.AddressesBlacklist,
  url: addresses_blacklist_url,
  enabled: !is_nil(addresses_blacklist_url),
  update_interval: ConfigHelper.parse_time_env_var("ADDRESSES_BLACKLIST_UPDATE_INTERVAL", "15m"),
  retry_interval: ConfigHelper.parse_time_env_var("ADDRESSES_BLACKLIST_RETRY_INTERVAL", "5s"),
  provider: ConfigHelper.parse_catalog_value("ADDRESSES_BLACKLIST_PROVIDER", ["blockaid"], false, "blockaid")

rate_limiter_redis_url = ConfigHelper.parse_url_env_var("RATE_LIMITER_REDIS_URL")

config :explorer, Explorer.Utility.RateLimiter,
  storage: (rate_limiter_redis_url && :redis) || :ets,
  redis_url: rate_limiter_redis_url,
  on_demand: [
    time_interval_limit: ConfigHelper.parse_time_env_var("RATE_LIMITER_ON_DEMAND_TIME_INTERVAL", "5s"),
    limit_by_ip: ConfigHelper.parse_integer_env_var("RATE_LIMITER_ON_DEMAND_LIMIT_BY_IP", 50),
    exp_timeout_coeff: ConfigHelper.parse_integer_env_var("RATE_LIMITER_ON_DEMAND_EXPONENTIAL_TIMEOUT_COEFF", 100),
    max_ban_interval: ConfigHelper.parse_time_env_var("RATE_LIMITER_ON_DEMAND_MAX_BAN_INTERVAL", "1h"),
    limitation_period: ConfigHelper.parse_time_env_var("RATE_LIMITER_ON_DEMAND_LIMITATION_PERIOD", "1h")
  ],
  hammer_backend_module:
    if(rate_limiter_redis_url, do: Explorer.Utility.Hammer.Redis, else: Explorer.Utility.Hammer.ETS)

universal_proxy_config_url =
  ConfigHelper.parse_url_env_var(
    "UNIVERSAL_PROXY_CONFIG_URL",
    "https://raw.githubusercontent.com/blockscout/backend-configs/refs/heads/main/universal-proxy-config.json"
  )

universal_proxy_config = System.get_env("UNIVERSAL_PROXY_CONFIG")

if System.get_env("UNIVERSAL_PROXY_CONFIG_URL") && universal_proxy_config do
  raise "UNIVERSAL_PROXY_CONFIG_URL and UNIVERSAL_PROXY_CONFIG are both set; choose only one"
end

config :explorer, Explorer.ThirdPartyIntegrations.UniversalProxy,
  config_url: universal_proxy_config_url,
  config_json: universal_proxy_config

config :explorer, Explorer.Chain.Mud, enabled: ConfigHelper.parse_bool_env_var("MUD_INDEXER_ENABLED")

config :explorer, Explorer.Chain.Scroll.L1FeeParam,
  curie_upgrade_block: ConfigHelper.parse_integer_env_var("SCROLL_L2_CURIE_UPGRADE_BLOCK", 0),
  scalar_init: ConfigHelper.parse_integer_env_var("SCROLL_L1_SCALAR_INIT", 0),
  overhead_init: ConfigHelper.parse_integer_env_var("SCROLL_L1_OVERHEAD_INIT", 0),
  commit_scalar_init: ConfigHelper.parse_integer_env_var("SCROLL_L1_COMMIT_SCALAR_INIT", 0),
  blob_scalar_init: ConfigHelper.parse_integer_env_var("SCROLL_L1_BLOB_SCALAR_INIT", 0),
  l1_base_fee_init: ConfigHelper.parse_integer_env_var("SCROLL_L1_BASE_FEE_INIT", 0),
  l1_blob_base_fee_init: ConfigHelper.parse_integer_env_var("SCROLL_L1_BLOB_BASE_FEE_INIT", 0)

###############
### Indexer ###
###############

first_block = ConfigHelper.parse_integer_env_var("FIRST_BLOCK", 0)
last_block = ConfigHelper.parse_integer_or_nil_env_var("LAST_BLOCK")

block_ranges = ConfigHelper.safe_get_env("BLOCK_RANGES", "#{first_block}..#{last_block || "latest"}")

trace_first_block = ConfigHelper.parse_integer_env_var("TRACE_FIRST_BLOCK", 0)
trace_last_block = ConfigHelper.parse_integer_or_nil_env_var("TRACE_LAST_BLOCK")

trace_block_ranges =
  case ConfigHelper.safe_get_env("TRACE_BLOCK_RANGES", nil) do
    "" -> "#{trace_first_block}..#{trace_last_block || "latest"}"
    ranges -> ranges
  end

disable_multichain_search_db_export_counters_queue_fetcher =
  ConfigHelper.parse_bool_env_var("INDEXER_DISABLE_MULTICHAIN_SEARCH_DB_EXPORT_COUNTERS_QUEUE_FETCHER")

optimism_l2_isthmus_timestamp =
  ConfigHelper.parse_integer_or_nil_env_var("INDEXER_OPTIMISM_L2_ISTHMUS_TIMESTAMP")

config :indexer,
  block_transformer: ConfigHelper.block_transformer(),
  chain_id: System.get_env("CHAIN_ID"),
  metadata_updater_milliseconds_interval: ConfigHelper.parse_time_env_var("TOKEN_METADATA_UPDATE_INTERVAL", "48h"),
  block_ranges: block_ranges,
  first_block: first_block,
  last_block: last_block,
  trace_block_ranges: trace_block_ranges,
  trace_first_block: trace_first_block,
  trace_last_block: trace_last_block,
  fetch_rewards_way: System.get_env("FETCH_REWARDS_WAY", "trace_block"),
  memory_limit: ConfigHelper.indexer_memory_limit(),
  system_memory_percentage: ConfigHelper.parse_integer_env_var("INDEXER_SYSTEM_MEMORY_PERCENTAGE", 60),
  receipts_batch_size: ConfigHelper.parse_integer_env_var("INDEXER_RECEIPTS_BATCH_SIZE", 250),
  receipts_concurrency: ConfigHelper.parse_integer_env_var("INDEXER_RECEIPTS_CONCURRENCY", 10),
  hide_indexing_progress_alert: ConfigHelper.parse_bool_env_var("INDEXER_HIDE_INDEXING_PROGRESS_ALERT"),
  fetcher_init_limit: ConfigHelper.parse_integer_env_var("INDEXER_FETCHER_INIT_QUERY_LIMIT", 100),
  token_balances_fetcher_init_limit:
    ConfigHelper.parse_integer_env_var("INDEXER_TOKEN_BALANCES_FETCHER_INIT_QUERY_LIMIT", 100_000),
  coin_balances_fetcher_init_limit:
    ConfigHelper.parse_integer_env_var("INDEXER_COIN_BALANCES_FETCHER_INIT_QUERY_LIMIT", 2_000),
  graceful_shutdown_period: ConfigHelper.parse_time_env_var("INDEXER_GRACEFUL_SHUTDOWN_PERIOD", "5m"),
  internal_transactions_fetch_order:
    ConfigHelper.parse_catalog_value("INDEXER_INTERNAL_TRANSACTIONS_FETCH_ORDER", ["asc", "desc"], true, "asc")

config :indexer, :ipfs,
  gateway_url: ConfigHelper.parse_url_env_var("IPFS_GATEWAY_URL", "https://ipfs.io/ipfs"),
  gateway_url_param_key: System.get_env("IPFS_GATEWAY_URL_PARAM_KEY"),
  gateway_url_param_value: System.get_env("IPFS_GATEWAY_URL_PARAM_VALUE"),
  gateway_url_param_location:
    ConfigHelper.parse_catalog_value("IPFS_GATEWAY_URL_PARAM_LOCATION", ["query", "header"], true),
  public_gateway_url: ConfigHelper.parse_url_env_var("IPFS_PUBLIC_GATEWAY_URL", "https://ipfs.io/ipfs")

config :indexer, :arc,
  arc_native_token_decimals: ConfigHelper.parse_integer_env_var("INDEXER_ARC_NATIVE_TOKEN_DECIMALS", 6),
  arc_native_token_address:
    System.get_env("INDEXER_ARC_NATIVE_TOKEN_CONTRACT", "0x3600000000000000000000000000000000000000"),
  arc_native_token_system_address:
    System.get_env("INDEXER_ARC_NATIVE_TOKEN_SYSTEM_CONTRACT", "0x1800000000000000000000000000000000000000")

config :indexer, Indexer.Supervisor, enabled: !disable_indexer?

config :indexer, Indexer.Fetcher.TransactionAction.Supervisor,
  enabled: ConfigHelper.parse_bool_env_var("INDEXER_TX_ACTIONS_ENABLE")

config :indexer, Indexer.Fetcher.TransactionAction,
  reindex_first_block: System.get_env("INDEXER_TX_ACTIONS_REINDEX_FIRST_BLOCK"),
  reindex_last_block: System.get_env("INDEXER_TX_ACTIONS_REINDEX_LAST_BLOCK"),
  reindex_protocols: System.get_env("INDEXER_TX_ACTIONS_REINDEX_PROTOCOLS", ""),
  aave_v3_pool: System.get_env("INDEXER_TX_ACTIONS_AAVE_V3_POOL_CONTRACT"),
  uniswap_v3_factory:
    ConfigHelper.safe_get_env(
      "INDEXER_TX_ACTIONS_UNISWAP_V3_FACTORY_CONTRACT",
      "0x1F98431c8aD98523631AE4a59f267346ea31F984"
    ),
  uniswap_v3_nft_position_manager:
    ConfigHelper.safe_get_env(
      "INDEXER_TX_ACTIONS_UNISWAP_V3_NFT_POSITION_MANAGER_CONTRACT",
      "0xC36442b4a4522E871399CD717aBDD847Ab11FE88"
    )

config :indexer, Indexer.PendingTransactionsSanitizer,
  interval: ConfigHelper.parse_time_env_var("INDEXER_PENDING_TRANSACTIONS_SANITIZER_INTERVAL", "1h")

config :indexer, Indexer.Fetcher.PendingTransaction.Supervisor,
  disabled?: ConfigHelper.parse_bool_env_var("INDEXER_DISABLE_PENDING_TRANSACTIONS_FETCHER")

config :indexer, Indexer.Fetcher.Token, concurrency: ConfigHelper.parse_integer_env_var("INDEXER_TOKEN_CONCURRENCY", 10)

config :indexer, Indexer.Fetcher.TokenBalance.Historical,
  batch_size: ConfigHelper.parse_integer_env_var("INDEXER_ARCHIVAL_TOKEN_BALANCES_BATCH_SIZE", 100),
  concurrency: ConfigHelper.parse_integer_env_var("INDEXER_ARCHIVAL_TOKEN_BALANCES_CONCURRENCY", 10),
  max_refetch_interval: ConfigHelper.parse_time_env_var("INDEXER_ARCHIVAL_TOKEN_BALANCES_MAX_REFETCH_INTERVAL", "168h"),
  exp_timeout_coeff:
    ConfigHelper.parse_integer_env_var("INDEXER_ARCHIVAL_TOKEN_BALANCES_EXPONENTIAL_TIMEOUT_COEFF", 100)

config :indexer, Indexer.Fetcher.TokenBalance.Historical.Supervisor,
  disabled?: ConfigHelper.parse_bool_env_var("INDEXER_DISABLE_ARCHIVAL_TOKEN_BALANCES_FETCHER")

config :indexer, Indexer.Fetcher.TokenBalance.Current,
  batch_size: ConfigHelper.parse_integer_env_var("INDEXER_CURRENT_TOKEN_BALANCES_BATCH_SIZE", 100),
  concurrency: ConfigHelper.parse_integer_env_var("INDEXER_CURRENT_TOKEN_BALANCES_CONCURRENCY", 10)

config :indexer, Indexer.Fetcher.TokenCountersUpdater,
  milliseconds_interval: ConfigHelper.parse_time_env_var("TOKEN_COUNTERS_UPDATE_INTERVAL", "3h")

config :indexer, Indexer.Fetcher.OnDemand.TokenBalance,
  threshold: ConfigHelper.parse_time_env_var("TOKEN_BALANCE_ON_DEMAND_FETCHER_THRESHOLD", "1h"),
  fallback_threshold_in_blocks: 500

config :indexer, Indexer.Fetcher.OnDemand.CoinBalance,
  threshold: ConfigHelper.parse_time_env_var("COIN_BALANCE_ON_DEMAND_FETCHER_THRESHOLD", "1h"),
  fallback_threshold_in_blocks: 500

config :indexer, Indexer.Fetcher.OnDemand.ContractCode,
  threshold: ConfigHelper.parse_time_env_var("CONTRACT_CODE_ON_DEMAND_FETCHER_THRESHOLD", "5s")

config :indexer, Indexer.Fetcher.OnDemand.TokenInstanceMetadataRefetch,
  threshold: ConfigHelper.parse_time_env_var("TOKEN_INSTANCE_METADATA_REFETCH_ON_DEMAND_FETCHER_THRESHOLD", "5s")

config :indexer, Indexer.Fetcher.BlockReward.Supervisor,
  disabled?: ConfigHelper.parse_bool_env_var("INDEXER_DISABLE_BLOCK_REWARD_FETCHER")

config :indexer, Indexer.Fetcher.InternalTransaction.Supervisor,
  disabled?: trace_url_missing? or ConfigHelper.parse_bool_env_var("INDEXER_DISABLE_INTERNAL_TRANSACTIONS_FETCHER")

disable_coin_balances_fetcher? = ConfigHelper.parse_bool_env_var("INDEXER_DISABLE_ADDRESS_COIN_BALANCE_FETCHER")

config :indexer, Indexer.Fetcher.CoinBalance.Catchup.Supervisor, disabled?: disable_coin_balances_fetcher?

config :indexer, Indexer.Fetcher.CoinBalance.Realtime.Supervisor, disabled?: disable_coin_balances_fetcher?

config :indexer, Indexer.Fetcher.TokenUpdater.Supervisor,
  disabled?: ConfigHelper.parse_bool_env_var("INDEXER_DISABLE_CATALOGED_TOKEN_UPDATER_FETCHER")

config :indexer, Indexer.Fetcher.TokenTotalSupplyUpdater.Supervisor,
  disabled?: ConfigHelper.parse_bool_env_var("INDEXER_DISABLE_CATALOGED_TOKEN_UPDATER_FETCHER")

config :indexer, Indexer.Fetcher.TokenCountersUpdater.Supervisor,
  disabled?: ConfigHelper.parse_bool_env_var("INDEXER_DISABLE_CATALOGED_TOKEN_UPDATER_FETCHER")

config :indexer, Indexer.Fetcher.EmptyBlocksSanitizer.Supervisor,
  disabled?: ConfigHelper.parse_bool_env_var("INDEXER_DISABLE_EMPTY_BLOCKS_SANITIZER")

config :indexer, Indexer.Block.Realtime.Supervisor,
  enabled: !ConfigHelper.parse_bool_env_var("DISABLE_REALTIME_INDEXER")

config :indexer, Indexer.Block.Catchup.Supervisor, enabled: !ConfigHelper.parse_bool_env_var("DISABLE_CATCHUP_INDEXER")

config :indexer, Indexer.Fetcher.ReplacedTransaction.Supervisor,
  disabled?: ConfigHelper.parse_bool_env_var("INDEXER_DISABLE_REPLACED_TRANSACTION_FETCHER")

config :indexer, Indexer.Fetcher.TokenInstance.Realtime.Supervisor,
  disabled?: ConfigHelper.parse_bool_env_var("INDEXER_DISABLE_TOKEN_INSTANCE_REALTIME_FETCHER")

config :indexer, Indexer.Fetcher.TokenInstance.Retry.Supervisor,
  disabled?: ConfigHelper.parse_bool_env_var("INDEXER_DISABLE_TOKEN_INSTANCE_RETRY_FETCHER")

config :indexer, Indexer.Fetcher.TokenInstance.Sanitize.Supervisor,
  disabled?: ConfigHelper.parse_bool_env_var("INDEXER_DISABLE_TOKEN_INSTANCE_SANITIZE_FETCHER")

config :indexer, Indexer.Fetcher.TokenInstance.Refetch.Supervisor,
  disabled?: ConfigHelper.parse_bool_env_var("INDEXER_DISABLE_TOKEN_INSTANCE_REFETCH_FETCHER")

config :indexer, Indexer.Fetcher.TokenInstance.SanitizeERC1155,
  enabled: !ConfigHelper.parse_bool_env_var("INDEXER_DISABLE_TOKEN_INSTANCE_ERC_1155_SANITIZE_FETCHER", "false")

config :indexer, Indexer.Fetcher.TokenInstance.SanitizeERC721,
  enabled: !ConfigHelper.parse_bool_env_var("INDEXER_DISABLE_TOKEN_INSTANCE_ERC_721_SANITIZE_FETCHER", "false")

config :indexer, Indexer.Fetcher.MultichainSearchDb.MainExportQueue.Supervisor,
  disabled?:
    ConfigHelper.parse_bool_env_var("INDEXER_DISABLE_MULTICHAIN_SEARCH_DB_EXPORT_MAIN_QUEUE_FETCHER") ||
      is_nil(microservice_multichain_search_url)

config :indexer, Indexer.Fetcher.MultichainSearchDb.BalancesExportQueue.Supervisor,
  disabled?:
    ConfigHelper.parse_bool_env_var("INDEXER_DISABLE_MULTICHAIN_SEARCH_DB_EXPORT_BALANCES_QUEUE_FETCHER") ||
      is_nil(microservice_multichain_search_url)

config :indexer, Indexer.Fetcher.MultichainSearchDb.TokenInfoExportQueue.Supervisor,
  disabled?:
    ConfigHelper.parse_bool_env_var("INDEXER_DISABLE_MULTICHAIN_SEARCH_DB_EXPORT_TOKEN_INFO_QUEUE_FETCHER") ||
      is_nil(microservice_multichain_search_url)

config :indexer, Indexer.Fetcher.MultichainSearchDb.CountersExportQueue.Supervisor,
  disabled?:
    disable_multichain_search_db_export_counters_queue_fetcher ||
      is_nil(microservice_multichain_search_url) ||
      !transactions_stats_enabled

config :indexer, Indexer.Fetcher.MultichainSearchDb.CountersFetcher.Supervisor,
  disabled?:
    disable_multichain_search_db_export_counters_queue_fetcher ||
      is_nil(microservice_multichain_search_url) ||
      !transactions_stats_enabled

config :indexer, Indexer.Fetcher.Stats.HotSmartContracts.Supervisor,
  disabled?: ConfigHelper.parse_bool_env_var("INDEXER_DISABLE_HOT_SMART_CONTRACTS_FETCHER"),
  enabled: !ConfigHelper.parse_bool_env_var("INDEXER_DISABLE_HOT_SMART_CONTRACTS_FETCHER")

config :indexer, Indexer.Fetcher.EmptyBlocksSanitizer,
  batch_size: ConfigHelper.parse_integer_env_var("INDEXER_EMPTY_BLOCKS_SANITIZER_BATCH_SIZE", 10),
  interval: ConfigHelper.parse_time_env_var("INDEXER_EMPTY_BLOCKS_SANITIZER_INTERVAL", "10s"),
  head_offset: ConfigHelper.parse_integer_env_var("INDEXER_EMPTY_BLOCKS_SANITIZER_HEAD_OFFSET", 1000)

config :indexer, Indexer.Block.Realtime.Fetcher,
  max_gap: ConfigHelper.parse_integer_env_var("INDEXER_REALTIME_FETCHER_MAX_GAP", 1_000),
  polling_period: ConfigHelper.parse_time_env_var("INDEXER_REALTIME_FETCHER_POLLING_PERIOD")

config :indexer, Indexer.Block.Catchup.MissingRangesCollector,
  batch_size: ConfigHelper.parse_integer_env_var("INDEXER_CATCHUP_MISSING_RANGES_BATCH_SIZE", 100_000)

config :indexer, Indexer.Block.Catchup.Fetcher,
  batch_size: ConfigHelper.parse_integer_env_var("INDEXER_CATCHUP_BLOCKS_BATCH_SIZE", 10),
  concurrency: ConfigHelper.parse_integer_env_var("INDEXER_CATCHUP_BLOCKS_CONCURRENCY", 10)

config :indexer, Indexer.Fetcher.BlockReward,
  batch_size: ConfigHelper.parse_integer_env_var("INDEXER_BLOCK_REWARD_BATCH_SIZE", 10),
  concurrency: ConfigHelper.parse_integer_env_var("INDEXER_BLOCK_REWARD_CONCURRENCY", 4)

config :indexer, Indexer.Fetcher.TokenInstance.Helper,
  base_uri_retry?: ConfigHelper.parse_bool_env_var("INDEXER_TOKEN_INSTANCE_USE_BASE_URI_RETRY"),
  cidr_blacklist: ConfigHelper.parse_list_env_var("INDEXER_TOKEN_INSTANCE_CIDR_BLACKLIST", ""),
  host_filtering_enabled?: ConfigHelper.parse_bool_env_var("INDEXER_TOKEN_INSTANCE_HOST_FILTERING_ENABLED", "true"),
  allowed_uri_protocols: ConfigHelper.parse_list_env_var("INDEXER_TOKEN_INSTANCE_ALLOWED_URI_PROTOCOLS", "http,https")

config :indexer, Indexer.Fetcher.TokenInstance.Retry,
  concurrency: ConfigHelper.parse_integer_env_var("INDEXER_TOKEN_INSTANCE_RETRY_CONCURRENCY", 10),
  batch_size: ConfigHelper.parse_integer_env_var("INDEXER_TOKEN_INSTANCE_RETRY_BATCH_SIZE", 10),
  max_refetch_interval: ConfigHelper.parse_time_env_var("INDEXER_TOKEN_INSTANCE_RETRY_MAX_REFETCH_INTERVAL", "168h"),
  exp_timeout_base: ConfigHelper.parse_integer_env_var("INDEXER_TOKEN_INSTANCE_RETRY_EXPONENTIAL_TIMEOUT_BASE", 2),
  exp_timeout_coeff: ConfigHelper.parse_integer_env_var("INDEXER_TOKEN_INSTANCE_RETRY_EXPONENTIAL_TIMEOUT_COEFF", 100)

config :indexer, Indexer.Fetcher.TokenInstance.Realtime,
  concurrency: ConfigHelper.parse_integer_env_var("INDEXER_TOKEN_INSTANCE_REALTIME_CONCURRENCY", 10),
  batch_size: ConfigHelper.parse_integer_env_var("INDEXER_TOKEN_INSTANCE_REALTIME_BATCH_SIZE", 1),
  retry_with_cooldown?: ConfigHelper.parse_bool_env_var("INDEXER_TOKEN_INSTANCE_REALTIME_RETRY_ENABLED"),
  retry_timeout: ConfigHelper.parse_time_env_var("INDEXER_TOKEN_INSTANCE_REALTIME_RETRY_TIMEOUT", "5s")

config :indexer, Indexer.Fetcher.TokenInstance.Sanitize,
  concurrency: ConfigHelper.parse_integer_env_var("INDEXER_TOKEN_INSTANCE_SANITIZE_CONCURRENCY", 10),
  batch_size: ConfigHelper.parse_integer_env_var("INDEXER_TOKEN_INSTANCE_SANITIZE_BATCH_SIZE", 10)

config :indexer, Indexer.Fetcher.TokenInstance.Refetch,
  concurrency: ConfigHelper.parse_integer_env_var("INDEXER_TOKEN_INSTANCE_REFETCH_CONCURRENCY", 10),
  batch_size: ConfigHelper.parse_integer_env_var("INDEXER_TOKEN_INSTANCE_REFETCH_BATCH_SIZE", 10)

config :indexer, Indexer.Fetcher.TokenInstance.SanitizeERC1155,
  concurrency: ConfigHelper.parse_integer_env_var("MIGRATION_TOKEN_INSTANCE_ERC_1155_SANITIZE_CONCURRENCY", 1),
  batch_size: ConfigHelper.parse_integer_env_var("MIGRATION_TOKEN_INSTANCE_ERC_1155_SANITIZE_BATCH_SIZE", 500)

config :indexer, Indexer.Fetcher.TokenInstance.SanitizeERC721,
  concurrency: ConfigHelper.parse_integer_env_var("MIGRATION_TOKEN_INSTANCE_ERC_721_SANITIZE_CONCURRENCY", 2),
  batch_size: ConfigHelper.parse_integer_env_var("MIGRATION_TOKEN_INSTANCE_ERC_721_SANITIZE_BATCH_SIZE", 50),
  tokens_queue_size:
    ConfigHelper.parse_integer_env_var("MIGRATION_TOKEN_INSTANCE_ERC_721_SANITIZE_TOKENS_BATCH_SIZE", 100)

config :indexer, Indexer.Fetcher.InternalTransaction,
  batch_size: ConfigHelper.parse_integer_env_var("INDEXER_INTERNAL_TRANSACTIONS_BATCH_SIZE", 10),
  concurrency: ConfigHelper.parse_integer_env_var("INDEXER_INTERNAL_TRANSACTIONS_CONCURRENCY", 4),
  indexing_finished_threshold:
    ConfigHelper.parse_integer_env_var("API_INTERNAL_TRANSACTIONS_INDEXING_FINISHED_THRESHOLD", 1_000)

config :indexer, Indexer.Fetcher.InternalTransaction.DeleteQueue,
  batch_size: ConfigHelper.parse_integer_env_var("INDEXER_INTERNAL_TRANSACTIONS_DELETE_QUEUE_BATCH_SIZE", 100),
  concurrency: ConfigHelper.parse_integer_env_var("INDEXER_INTERNAL_TRANSACTIONS_DELETE_QUEUE_CONCURRENCY", 1),
  threshold: ConfigHelper.parse_time_env_var("INDEXER_INTERNAL_TRANSACTIONS_DELETE_QUEUE_THRESHOLD", "0s")

coin_balances_batch_size = ConfigHelper.parse_integer_env_var("INDEXER_COIN_BALANCES_BATCH_SIZE", 100)
coin_balances_concurrency = ConfigHelper.parse_integer_env_var("INDEXER_COIN_BALANCES_CONCURRENCY", 4)

config :indexer, Indexer.Fetcher.CoinBalance.Catchup,
  batch_size: coin_balances_batch_size,
  concurrency: coin_balances_concurrency

config :indexer, Indexer.Fetcher.CoinBalance.Realtime,
  batch_size: coin_balances_batch_size,
  concurrency: coin_balances_concurrency

config :indexer, Indexer.Migrator.RecoveryWETHTokenTransfers,
  concurrency: ConfigHelper.parse_integer_env_var("MIGRATION_RECOVERY_WETH_TOKEN_TRANSFERS_CONCURRENCY", 5),
  batch_size: ConfigHelper.parse_integer_env_var("MIGRATION_RECOVERY_WETH_TOKEN_TRANSFERS_BATCH_SIZE", 50),
  timeout: ConfigHelper.parse_time_env_var("MIGRATION_RECOVERY_WETH_TOKEN_TRANSFERS_TIMEOUT", "0s"),
  blocks_batch_size:
    ConfigHelper.parse_integer_env_var("MIGRATION_RECOVERY_WETH_TOKEN_TRANSFERS_BLOCKS_BATCH_SIZE", 100_000),
  high_verbosity: ConfigHelper.parse_bool_env_var("MIGRATION_RECOVERY_WETH_TOKEN_TRANSFERS_HIGH_VERBOSITY", "true")

config :indexer, Indexer.Fetcher.MultichainSearchDb.MainExportQueue,
  concurrency: ConfigHelper.parse_integer_env_var("INDEXER_MULTICHAIN_SEARCH_DB_EXPORT_MAIN_QUEUE_CONCURRENCY", 10),
  batch_size: ConfigHelper.parse_integer_env_var("INDEXER_MULTICHAIN_SEARCH_DB_EXPORT_MAIN_QUEUE_BATCH_SIZE", 3_000),
  enqueue_busy_waiting_timeout:
    ConfigHelper.parse_time_env_var(
      "INDEXER_MULTICHAIN_SEARCH_DB_EXPORT_MAIN_QUEUE_ENQUEUE_BUSY_WAITING_TIMEOUT",
      "1s"
    ),
  max_queue_size:
    ConfigHelper.parse_integer_env_var("INDEXER_MULTICHAIN_SEARCH_DB_EXPORT_MAIN_QUEUE_MAX_QUEUE_SIZE", 3_000),
  init_limit:
    ConfigHelper.parse_integer_env_var("INDEXER_MULTICHAIN_SEARCH_DB_EXPORT_MAIN_QUEUE_INIT_QUERY_LIMIT", 3_000)

config :indexer, Indexer.Fetcher.MultichainSearchDb.BalancesExportQueue,
  concurrency: ConfigHelper.parse_integer_env_var("INDEXER_MULTICHAIN_SEARCH_DB_EXPORT_BALANCES_QUEUE_CONCURRENCY", 10),
  batch_size:
    ConfigHelper.parse_integer_env_var("INDEXER_MULTICHAIN_SEARCH_DB_EXPORT_BALANCES_QUEUE_BATCH_SIZE", 3_000),
  enqueue_busy_waiting_timeout:
    ConfigHelper.parse_time_env_var(
      "INDEXER_MULTICHAIN_SEARCH_DB_EXPORT_BALANCES_QUEUE_ENQUEUE_BUSY_WAITING_TIMEOUT",
      "1s"
    ),
  max_queue_size:
    ConfigHelper.parse_integer_env_var(
      "INDEXER_MULTICHAIN_SEARCH_DB_EXPORT_BALANCES_QUEUE_MAX_QUEUE_SIZE",
      3_000
    ),
  init_limit:
    ConfigHelper.parse_integer_env_var("INDEXER_MULTICHAIN_SEARCH_DB_EXPORT_BALANCES_QUEUE_INIT_QUERY_LIMIT", 3_000)

config :indexer, Indexer.Fetcher.MultichainSearchDb.TokenInfoExportQueue,
  concurrency:
    ConfigHelper.parse_integer_env_var("INDEXER_MULTICHAIN_SEARCH_DB_EXPORT_TOKEN_INFO_QUEUE_CONCURRENCY", 10),
  batch_size:
    ConfigHelper.parse_integer_env_var("INDEXER_MULTICHAIN_SEARCH_DB_EXPORT_TOKEN_INFO_QUEUE_BATCH_SIZE", 1_000),
  enqueue_busy_waiting_timeout:
    ConfigHelper.parse_time_env_var(
      "INDEXER_MULTICHAIN_SEARCH_DB_EXPORT_TOKEN_INFO_QUEUE_ENQUEUE_BUSY_WAITING_TIMEOUT",
      "1s"
    ),
  max_queue_size:
    ConfigHelper.parse_integer_env_var("INDEXER_MULTICHAIN_SEARCH_DB_EXPORT_TOKEN_INFO_QUEUE_MAX_QUEUE_SIZE", 1_000),
  init_limit:
    ConfigHelper.parse_integer_env_var("INDEXER_MULTICHAIN_SEARCH_DB_EXPORT_TOKEN_INFO_QUEUE_INIT_QUERY_LIMIT", 1_000)

config :indexer, Indexer.Fetcher.MultichainSearchDb.CountersExportQueue,
  concurrency: ConfigHelper.parse_integer_env_var("INDEXER_MULTICHAIN_SEARCH_DB_EXPORT_COUNTERS_QUEUE_CONCURRENCY", 10),
  batch_size:
    ConfigHelper.parse_integer_env_var("INDEXER_MULTICHAIN_SEARCH_DB_EXPORT_COUNTERS_QUEUE_BATCH_SIZE", 1_000),
  enqueue_busy_waiting_timeout:
    ConfigHelper.parse_time_env_var(
      "INDEXER_MULTICHAIN_SEARCH_DB_EXPORT_COUNTERS_QUEUE_ENQUEUE_BUSY_WAITING_TIMEOUT",
      "1s"
    ),
  max_queue_size:
    ConfigHelper.parse_integer_env_var("INDEXER_MULTICHAIN_SEARCH_DB_EXPORT_COUNTERS_QUEUE_MAX_QUEUE_SIZE", 1_000),
  init_limit:
    ConfigHelper.parse_integer_env_var("INDEXER_MULTICHAIN_SEARCH_DB_EXPORT_COUNTERS_QUEUE_INIT_QUERY_LIMIT", 1_000)

config :indexer, Indexer.Fetcher.SignedAuthorizationStatus,
  batch_size: ConfigHelper.parse_integer_env_var("INDEXER_SIGNED_AUTHORIZATION_STATUS_BATCH_SIZE", 10)

config :indexer, Indexer.Fetcher.Optimism.TransactionBatch.Supervisor, enabled: ConfigHelper.chain_type() == :optimism
config :indexer, Indexer.Fetcher.Optimism.OutputRoot.Supervisor, enabled: ConfigHelper.chain_type() == :optimism
config :indexer, Indexer.Fetcher.Optimism.DisputeGame.Supervisor, enabled: ConfigHelper.chain_type() == :optimism
config :indexer, Indexer.Fetcher.Optimism.Deposit.Supervisor, enabled: ConfigHelper.chain_type() == :optimism
config :indexer, Indexer.Fetcher.Optimism.Withdrawal.Supervisor, enabled: ConfigHelper.chain_type() == :optimism
config :indexer, Indexer.Fetcher.Optimism.WithdrawalEvent.Supervisor, enabled: ConfigHelper.chain_type() == :optimism

config :indexer, Indexer.Fetcher.Optimism.EIP1559ConfigUpdate.Supervisor,
  disabled?: ConfigHelper.chain_type() != :optimism

config :indexer, Indexer.Fetcher.Optimism.Interop.Message.Supervisor, disabled?: ConfigHelper.chain_type() != :optimism

config :indexer, Indexer.Fetcher.Optimism.Interop.MessageFailed.Supervisor,
  disabled?: ConfigHelper.chain_type() != :optimism

config :indexer, Indexer.Fetcher.Optimism.Interop.MessageQueue.Supervisor,
  disabled?: ConfigHelper.chain_type() != :optimism

config :indexer, Indexer.Fetcher.Optimism.Interop.MultichainExport.Supervisor,
  disabled?:
    ConfigHelper.chain_type() != :optimism ||
      ConfigHelper.parse_bool_env_var("INDEXER_DISABLE_OPTIMISM_INTEROP_MULTICHAIN_EXPORT", "true")

config :indexer, Indexer.Fetcher.Optimism,
  optimism_l1_rpc: System.get_env("INDEXER_OPTIMISM_L1_RPC"),
  optimism_l1_system_config: System.get_env("INDEXER_OPTIMISM_L1_SYSTEM_CONFIG_CONTRACT"),
  l1_eth_get_logs_range_size: ConfigHelper.parse_integer_env_var("INDEXER_OPTIMISM_L1_ETH_GET_LOGS_RANGE_SIZE", 250),
  l2_eth_get_logs_range_size: ConfigHelper.parse_integer_env_var("INDEXER_OPTIMISM_L2_ETH_GET_LOGS_RANGE_SIZE", 250),
  block_duration: ConfigHelper.parse_integer_env_var("INDEXER_OPTIMISM_BLOCK_DURATION", 2),
  start_block_l1: ConfigHelper.parse_integer_or_nil_env_var("INDEXER_OPTIMISM_L1_START_BLOCK"),
  portal: System.get_env("INDEXER_OPTIMISM_L1_PORTAL_CONTRACT"),
  isthmus_timestamp_l2: optimism_l2_isthmus_timestamp

config :indexer, Indexer.Fetcher.Optimism.Deposit,
  transaction_type: ConfigHelper.parse_integer_env_var("INDEXER_OPTIMISM_L1_DEPOSITS_TRANSACTION_TYPE", 126)

config :indexer, Indexer.Fetcher.Optimism.OutputRoot,
  output_oracle: System.get_env("INDEXER_OPTIMISM_L1_OUTPUT_ORACLE_CONTRACT")

config :indexer, Indexer.Fetcher.Optimism.Withdrawal,
  start_block_l2: System.get_env("INDEXER_OPTIMISM_L2_WITHDRAWALS_START_BLOCK", "1"),
  message_passer:
    System.get_env("INDEXER_OPTIMISM_L2_MESSAGE_PASSER_CONTRACT", "0x4200000000000000000000000000000000000016")

config :indexer, Indexer.Fetcher.Optimism.TransactionBatch,
  blocks_chunk_size: System.get_env("INDEXER_OPTIMISM_L1_BATCH_BLOCKS_CHUNK_SIZE", "4"),
  eip4844_blobs_api_url: System.get_env("INDEXER_OPTIMISM_L1_BATCH_BLOCKSCOUT_BLOBS_API_URL", ""),
  celestia_blobs_api_url: System.get_env("INDEXER_OPTIMISM_L1_BATCH_CELESTIA_BLOBS_API_URL", ""),
  eigenda_blobs_api_url: ConfigHelper.parse_url_env_var("INDEXER_OPTIMISM_L1_BATCH_EIGENDA_BLOBS_API_URL", ""),
  eigenda_proxy_base_url: ConfigHelper.parse_url_env_var("INDEXER_OPTIMISM_L1_BATCH_EIGENDA_PROXY_BASE_URL"),
  alt_da_server_url: System.get_env("INDEXER_OPTIMISM_L1_BATCH_ALT_DA_SERVER_URL", ""),
  genesis_block_l2: ConfigHelper.parse_integer_or_nil_env_var("INDEXER_OPTIMISM_L2_BATCH_GENESIS_BLOCK_NUMBER"),
  inbox: System.get_env("INDEXER_OPTIMISM_L1_BATCH_INBOX"),
  submitter: System.get_env("INDEXER_OPTIMISM_L1_BATCH_SUBMITTER")

config :indexer, Indexer.Fetcher.Optimism.EIP1559ConfigUpdate,
  chunk_size: ConfigHelper.parse_integer_env_var("INDEXER_OPTIMISM_L2_HOLOCENE_BLOCKS_CHUNK_SIZE", 25),
  holocene_timestamp_l2: ConfigHelper.parse_integer_or_nil_env_var("INDEXER_OPTIMISM_L2_HOLOCENE_TIMESTAMP"),
  jovian_timestamp_l2: ConfigHelper.parse_integer_or_nil_env_var("INDEXER_OPTIMISM_L2_JOVIAN_TIMESTAMP")

config :indexer, Indexer.Fetcher.Optimism.Interop.Message,
  start_block: ConfigHelper.parse_integer_or_nil_env_var("INDEXER_OPTIMISM_L2_INTEROP_START_BLOCK"),
  blocks_chunk_size: ConfigHelper.parse_integer_env_var("INDEXER_OPTIMISM_L2_INTEROP_BLOCKS_CHUNK_SIZE", 4)

config :indexer, Indexer.Fetcher.Optimism.Interop.MessageQueue,
  chainscout_api_url: ConfigHelper.parse_url_env_var("INDEXER_OPTIMISM_CHAINSCOUT_API_URL", nil, true),
  chainscout_fallback_map: ConfigHelper.parse_json_env_var("INDEXER_OPTIMISM_CHAINSCOUT_FALLBACK_MAP"),
  private_key: System.get_env("INDEXER_OPTIMISM_INTEROP_PRIVATE_KEY", ""),
  connect_timeout: ConfigHelper.parse_integer_env_var("INDEXER_OPTIMISM_INTEROP_CONNECT_TIMEOUT", 8),
  recv_timeout: ConfigHelper.parse_integer_env_var("INDEXER_OPTIMISM_INTEROP_RECV_TIMEOUT", 10),
  export_expiration: ConfigHelper.parse_integer_env_var("INDEXER_OPTIMISM_INTEROP_EXPORT_EXPIRATION_DAYS", 10)

config :indexer, Indexer.Fetcher.Optimism.Interop.MultichainExport,
  batch_size: ConfigHelper.parse_integer_env_var("INDEXER_OPTIMISM_MULTICHAIN_BATCH_SIZE", 100)

config :indexer, Indexer.Fetcher.Optimism.OperatorFee,
  concurrency: ConfigHelper.parse_integer_env_var("INDEXER_OPTIMISM_OPERATOR_FEE_QUEUE_CONCURRENCY", 3),
  batch_size: ConfigHelper.parse_integer_env_var("INDEXER_OPTIMISM_OPERATOR_FEE_QUEUE_BATCH_SIZE", 100),
  enqueue_busy_waiting_timeout:
    ConfigHelper.parse_time_env_var(
      "INDEXER_OPTIMISM_OPERATOR_FEE_QUEUE_ENQUEUE_BUSY_WAITING_TIMEOUT",
      "1s"
    ),
  max_queue_size: ConfigHelper.parse_integer_env_var("INDEXER_OPTIMISM_OPERATOR_FEE_QUEUE_MAX_QUEUE_SIZE", 1_000),
  init_limit: ConfigHelper.parse_integer_env_var("INDEXER_OPTIMISM_OPERATOR_FEE_QUEUE_INIT_QUERY_LIMIT", 1_000)

config :indexer, Indexer.Fetcher.Optimism.OperatorFee.Supervisor,
  disabled?: is_nil(optimism_l2_isthmus_timestamp) or ConfigHelper.chain_type() != :optimism

config :indexer, Indexer.Fetcher.Withdrawal.Supervisor,
  disabled?: System.get_env("INDEXER_DISABLE_WITHDRAWALS_FETCHER", "true") == "true"

config :indexer, Indexer.Fetcher.Withdrawal, first_block: System.get_env("WITHDRAWALS_FIRST_BLOCK")

config :indexer, Indexer.Fetcher.ZkSync.TransactionBatch,
  chunk_size: ConfigHelper.parse_integer_env_var("INDEXER_ZKSYNC_BATCHES_CHUNK_SIZE", 50),
  batches_max_range: ConfigHelper.parse_integer_env_var("INDEXER_ZKSYNC_NEW_BATCHES_MAX_RANGE", 50),
  recheck_interval: ConfigHelper.parse_integer_env_var("INDEXER_ZKSYNC_NEW_BATCHES_RECHECK_INTERVAL", 60)

config :indexer, Indexer.Fetcher.ZkSync.TransactionBatch.Supervisor,
  enabled: ConfigHelper.parse_bool_env_var("INDEXER_ZKSYNC_BATCHES_ENABLED")

config :indexer, Indexer.Fetcher.ZkSync.BatchesStatusTracker,
  zksync_l1_rpc: System.get_env("INDEXER_ZKSYNC_L1_RPC"),
  recheck_interval: ConfigHelper.parse_integer_env_var("INDEXER_ZKSYNC_BATCHES_STATUS_RECHECK_INTERVAL", 60)

config :indexer, Indexer.Fetcher.ZkSync.BatchesStatusTracker.Supervisor,
  enabled: ConfigHelper.parse_bool_env_var("INDEXER_ZKSYNC_BATCHES_ENABLED")

config :indexer, Indexer.Fetcher.Arbitrum.Messaging,
  arbsys_contract:
    ConfigHelper.safe_get_env("INDEXER_ARBITRUM_ARBSYS_CONTRACT", "0x0000000000000000000000000000000000000064")

config :indexer, Indexer.Fetcher.Arbitrum,
  l1_rpc: System.get_env("INDEXER_ARBITRUM_L1_RPC"),
  l1_rpc_chunk_size: ConfigHelper.parse_integer_env_var("INDEXER_ARBITRUM_L1_RPC_CHUNK_SIZE", 20),
  l1_rpc_block_range: ConfigHelper.parse_integer_env_var("INDEXER_ARBITRUM_L1_RPC_HISTORICAL_BLOCKS_RANGE", 1_000),
  l1_rollup_address: System.get_env("INDEXER_ARBITRUM_L1_ROLLUP_CONTRACT"),
  l1_rollup_init_block: ConfigHelper.parse_integer_env_var("INDEXER_ARBITRUM_L1_ROLLUP_INIT_BLOCK", 1),
  l1_start_block: ConfigHelper.parse_integer_env_var("INDEXER_ARBITRUM_L1_COMMON_START_BLOCK", 0),
  l1_finalization_threshold: ConfigHelper.parse_integer_env_var("INDEXER_ARBITRUM_L1_FINALIZATION_THRESHOLD", 1_000),
  rollup_chunk_size: ConfigHelper.parse_integer_env_var("INDEXER_ARBITRUM_ROLLUP_CHUNK_SIZE", 20)

config :indexer, Indexer.Fetcher.Arbitrum.TrackingMessagesOnL1,
  recheck_interval: ConfigHelper.parse_time_env_var("INDEXER_ARBITRUM_TRACKING_MESSAGES_ON_L1_RECHECK_INTERVAL", "20s"),
  failure_interval_threshold:
    ConfigHelper.parse_time_env_var("INDEXER_ARBITRUM_MESSAGES_TRACKING_FAILURE_THRESHOLD", "10m"),
  missed_message_ids_range: ConfigHelper.parse_integer_env_var("INDEXER_ARBITRUM_MISSED_MESSAGE_IDS_RANGE", 10_000)

config :indexer, Indexer.Fetcher.Arbitrum.TrackingMessagesOnL1.Supervisor,
  enabled: ConfigHelper.parse_bool_env_var("INDEXER_ARBITRUM_BRIDGE_MESSAGES_TRACKING_ENABLED")

config :indexer, Indexer.Fetcher.Arbitrum.TrackingBatchesStatuses,
  recheck_interval: ConfigHelper.parse_time_env_var("INDEXER_ARBITRUM_BATCHES_TRACKING_RECHECK_INTERVAL", "20s"),
  track_l1_transaction_finalization:
    ConfigHelper.parse_bool_env_var("INDEXER_ARBITRUM_BATCHES_TRACKING_L1_FINALIZATION_CHECK_ENABLED", "false"),
  messages_to_blocks_shift:
    ConfigHelper.parse_integer_env_var("INDEXER_ARBITRUM_BATCHES_TRACKING_MESSAGES_TO_BLOCKS_SHIFT", 0),
  finalized_confirmations: ConfigHelper.parse_bool_env_var("INDEXER_ARBITRUM_CONFIRMATIONS_TRACKING_FINALIZED", "true"),
  new_batches_limit: ConfigHelper.parse_integer_env_var("INDEXER_ARBITRUM_NEW_BATCHES_LIMIT", 10),
  node_interface_contract:
    ConfigHelper.safe_get_env("INDEXER_ARBITRUM_NODE_INTERFACE_CONTRACT", "0x00000000000000000000000000000000000000C8"),
  missing_batches_range: ConfigHelper.parse_integer_env_var("INDEXER_ARBITRUM_MISSING_BATCHES_RANGE", 10_000),
  failure_interval_threshold:
    ConfigHelper.parse_time_env_var("INDEXER_ARBITRUM_BATCHES_TRACKING_FAILURE_THRESHOLD", "10m")

config :indexer, Indexer.Fetcher.Arbitrum.TrackingBatchesStatuses.Supervisor,
  enabled: ConfigHelper.parse_bool_env_var("INDEXER_ARBITRUM_BATCHES_TRACKING_ENABLED")

config :indexer, Indexer.Fetcher.Arbitrum.RollupMessagesCatchup,
  recheck_interval: ConfigHelper.parse_time_env_var("INDEXER_ARBITRUM_MISSED_MESSAGES_RECHECK_INTERVAL", "1h"),
  missed_messages_blocks_depth:
    ConfigHelper.parse_integer_env_var("INDEXER_ARBITRUM_MISSED_MESSAGES_BLOCKS_DEPTH", 10_000)

config :indexer, Indexer.Fetcher.Arbitrum.RollupMessagesCatchup.Supervisor,
  enabled: ConfigHelper.parse_bool_env_var("INDEXER_ARBITRUM_BRIDGE_MESSAGES_TRACKING_ENABLED")

config :indexer, Indexer.Fetcher.Arbitrum.MessagesToL2Matcher.Supervisor,
  disabled?: not ConfigHelper.parse_bool_env_var("INDEXER_ARBITRUM_BRIDGE_MESSAGES_TRACKING_ENABLED")

config :indexer, Indexer.Fetcher.Arbitrum.DataBackfill,
  recheck_interval:
    ConfigHelper.parse_time_env_var("INDEXER_ARBITRUM_DATA_BACKFILL_UNINDEXED_BLOCKS_RECHECK_INTERVAL", "120s"),
  backfill_blocks_depth: ConfigHelper.parse_integer_env_var("INDEXER_ARBITRUM_DATA_BACKFILL_BLOCKS_DEPTH", 500)

config :indexer, Indexer.Fetcher.Arbitrum.DataBackfill.Supervisor,
  disabled?:
    ConfigHelper.chain_type() != :arbitrum ||
      not ConfigHelper.parse_bool_env_var("INDEXER_ARBITRUM_DATA_BACKFILL_ENABLED")

config :indexer, Indexer.Fetcher.RootstockData.Supervisor,
  disabled?:
    ConfigHelper.chain_type() != :rsk || ConfigHelper.parse_bool_env_var("INDEXER_DISABLE_ROOTSTOCK_DATA_FETCHER")

config :indexer, Indexer.Fetcher.RootstockData,
  interval: ConfigHelper.parse_time_env_var("INDEXER_ROOTSTOCK_DATA_FETCHER_INTERVAL", "3s"),
  batch_size: ConfigHelper.parse_integer_env_var("INDEXER_ROOTSTOCK_DATA_FETCHER_BATCH_SIZE", 10),
  max_concurrency: ConfigHelper.parse_integer_env_var("INDEXER_ROOTSTOCK_DATA_FETCHER_CONCURRENCY", 5),
  db_batch_size: ConfigHelper.parse_integer_env_var("INDEXER_ROOTSTOCK_DATA_FETCHER_DB_BATCH_SIZE", 300)

config :indexer, Indexer.Fetcher.Beacon, beacon_rpc: System.get_env("INDEXER_BEACON_RPC_URL") || "http://localhost:5052"

config :indexer, Indexer.Fetcher.Beacon.Blob.Supervisor,
  disabled?:
    ConfigHelper.chain_type() != :ethereum ||
      ConfigHelper.parse_bool_env_var("INDEXER_DISABLE_BEACON_BLOB_FETCHER")

config :indexer, Indexer.Fetcher.Beacon.Blob,
  slot_duration: ConfigHelper.parse_integer_env_var("INDEXER_BEACON_BLOB_FETCHER_SLOT_DURATION", 12),
  reference_slot: ConfigHelper.parse_integer_env_var("INDEXER_BEACON_BLOB_FETCHER_REFERENCE_SLOT", 8_000_000),
  reference_timestamp:
    ConfigHelper.parse_integer_env_var("INDEXER_BEACON_BLOB_FETCHER_REFERENCE_TIMESTAMP", 1_702_824_023),
  start_block: ConfigHelper.parse_integer_env_var("INDEXER_BEACON_BLOB_FETCHER_START_BLOCK", 19_200_000),
  end_block: ConfigHelper.parse_integer_env_var("INDEXER_BEACON_BLOB_FETCHER_END_BLOCK", 0)

config :indexer, Indexer.Fetcher.Beacon.Deposit.Supervisor,
  disabled?:
    ConfigHelper.chain_type() != :ethereum ||
      ConfigHelper.parse_bool_env_var("INDEXER_DISABLE_BEACON_DEPOSIT_FETCHER")

config :indexer, Indexer.Fetcher.Beacon.Deposit,
  interval: ConfigHelper.parse_time_env_var("INDEXER_BEACON_DEPOSIT_FETCHER_INTERVAL", "6s"),
  batch_size: ConfigHelper.parse_integer_env_var("INDEXER_BEACON_DEPOSIT_FETCHER_BATCH_SIZE", 1_000)

config :indexer, Indexer.Fetcher.Beacon.Deposit.Status.Supervisor,
  disabled?:
    ConfigHelper.chain_type() != :ethereum ||
      ConfigHelper.parse_bool_env_var("INDEXER_DISABLE_BEACON_DEPOSIT_STATUS_FETCHER")

config :indexer, Indexer.Fetcher.Beacon.Deposit.Status,
  epoch_duration: ConfigHelper.parse_integer_env_var("INDEXER_BEACON_DEPOSIT_STATUS_FETCHER_EPOCH_DURATION", 384),
  reference_timestamp:
    ConfigHelper.parse_integer_env_var("INDEXER_BEACON_DEPOSIT_STATUS_FETCHER_REFERENCE_TIMESTAMP", 1_722_024_023)

config :indexer, Indexer.Fetcher.Shibarium.L1,
  rpc: System.get_env("INDEXER_SHIBARIUM_L1_RPC"),
  start_block: System.get_env("INDEXER_SHIBARIUM_L1_START_BLOCK"),
  deposit_manager_proxy: System.get_env("INDEXER_SHIBARIUM_L1_DEPOSIT_MANAGER_CONTRACT"),
  ether_predicate_proxy: System.get_env("INDEXER_SHIBARIUM_L1_ETHER_PREDICATE_CONTRACT"),
  erc20_predicate_proxy: System.get_env("INDEXER_SHIBARIUM_L1_ERC20_PREDICATE_CONTRACT"),
  erc721_predicate_proxy: System.get_env("INDEXER_SHIBARIUM_L1_ERC721_PREDICATE_CONTRACT"),
  erc1155_predicate_proxy: System.get_env("INDEXER_SHIBARIUM_L1_ERC1155_PREDICATE_CONTRACT"),
  withdraw_manager_proxy: System.get_env("INDEXER_SHIBARIUM_L1_WITHDRAW_MANAGER_CONTRACT")

config :indexer, Indexer.Fetcher.Shibarium.L2,
  start_block: System.get_env("INDEXER_SHIBARIUM_L2_START_BLOCK"),
  child_chain: System.get_env("INDEXER_SHIBARIUM_L2_CHILD_CHAIN_CONTRACT"),
  weth: System.get_env("INDEXER_SHIBARIUM_L2_WETH_CONTRACT"),
  bone_withdraw: System.get_env("INDEXER_SHIBARIUM_L2_BONE_WITHDRAW_CONTRACT")

config :indexer, Indexer.Fetcher.Shibarium.L1.Supervisor, enabled: ConfigHelper.chain_type() == :shibarium

config :indexer, Indexer.Fetcher.Shibarium.L2.Supervisor, enabled: ConfigHelper.chain_type() == :shibarium

config :indexer, Indexer.Fetcher.PolygonZkevm.BridgeL1,
  rpc: System.get_env("INDEXER_POLYGON_ZKEVM_L1_RPC"),
  start_block: System.get_env("INDEXER_POLYGON_ZKEVM_L1_BRIDGE_START_BLOCK"),
  bridge_contract: System.get_env("INDEXER_POLYGON_ZKEVM_L1_BRIDGE_CONTRACT"),
  native_symbol: System.get_env("INDEXER_POLYGON_ZKEVM_L1_BRIDGE_NATIVE_SYMBOL", "ETH"),
  native_decimals: ConfigHelper.parse_integer_env_var("INDEXER_POLYGON_ZKEVM_L1_BRIDGE_NATIVE_DECIMALS", 18),
  rollup_network_id_l1: ConfigHelper.parse_integer_or_nil_env_var("INDEXER_POLYGON_ZKEVM_L1_BRIDGE_NETWORK_ID"),
  rollup_index_l1: ConfigHelper.parse_integer_or_nil_env_var("INDEXER_POLYGON_ZKEVM_L1_BRIDGE_ROLLUP_INDEX")

config :indexer, Indexer.Fetcher.PolygonZkevm.BridgeL1.Supervisor, enabled: ConfigHelper.chain_type() == :polygon_zkevm

config :indexer, Indexer.Fetcher.PolygonZkevm.BridgeL1Tokens.Supervisor,
  enabled: ConfigHelper.chain_type() == :polygon_zkevm

config :indexer, Indexer.Fetcher.PolygonZkevm.BridgeL2,
  start_block: System.get_env("INDEXER_POLYGON_ZKEVM_L2_BRIDGE_START_BLOCK"),
  bridge_contract: System.get_env("INDEXER_POLYGON_ZKEVM_L2_BRIDGE_CONTRACT"),
  rollup_network_id_l2: ConfigHelper.parse_integer_or_nil_env_var("INDEXER_POLYGON_ZKEVM_L2_BRIDGE_NETWORK_ID"),
  rollup_index_l2: ConfigHelper.parse_integer_or_nil_env_var("INDEXER_POLYGON_ZKEVM_L2_BRIDGE_ROLLUP_INDEX")

config :indexer, Indexer.Fetcher.PolygonZkevm.BridgeL2.Supervisor, enabled: ConfigHelper.chain_type() == :polygon_zkevm

config :indexer, Indexer.Fetcher.PolygonZkevm.TransactionBatch,
  chunk_size: ConfigHelper.parse_integer_env_var("INDEXER_POLYGON_ZKEVM_BATCHES_CHUNK_SIZE", 20),
  ignore_numbers: System.get_env("INDEXER_POLYGON_ZKEVM_BATCHES_IGNORE", "0"),
  recheck_interval: ConfigHelper.parse_integer_env_var("INDEXER_POLYGON_ZKEVM_BATCHES_RECHECK_INTERVAL", 60)

config :indexer, Indexer.Fetcher.PolygonZkevm.TransactionBatch.Supervisor,
  enabled:
    ConfigHelper.chain_type() == :polygon_zkevm &&
      ConfigHelper.parse_bool_env_var("INDEXER_POLYGON_ZKEVM_BATCHES_ENABLED")

config :indexer, Indexer.Fetcher.Celo.ValidatorGroupVotes,
  batch_size: ConfigHelper.parse_integer_env_var("INDEXER_CELO_VALIDATOR_GROUP_VOTES_BATCH_SIZE", 200_000)

config :indexer, Indexer.Fetcher.Celo.ValidatorGroupVotes.Supervisor,
  enabled:
    ConfigHelper.chain_identity() == {:optimism, :celo} and
      not ConfigHelper.parse_bool_env_var("INDEXER_DISABLE_CELO_VALIDATOR_GROUP_VOTES_FETCHER")

celo_epoch_fetchers_enabled? =
  ConfigHelper.chain_identity() == {:optimism, :celo} and
    not ConfigHelper.parse_bool_env_var("INDEXER_DISABLE_CELO_EPOCH_FETCHER")

config :indexer, Indexer.Fetcher.Celo.EpochBlockOperations.Supervisor,
  enabled: celo_epoch_fetchers_enabled?,
  disabled?: not celo_epoch_fetchers_enabled?

config :indexer, Indexer.Fetcher.Celo.Legacy.Account,
  concurrency: ConfigHelper.parse_integer_env_var("INDEXER_CELO_ACCOUNTS_CONCURRENCY", 1),
  batch_size: ConfigHelper.parse_integer_env_var("INDEXER_CELO_ACCOUNTS_BATCH_SIZE", 100)

config :indexer, Indexer.Fetcher.Celo.Legacy.Account.Supervisor,
  enabled: ConfigHelper.chain_identity() == {:optimism, :celo},
  disabled?: not (ConfigHelper.chain_identity() == {:optimism, :celo})

config :indexer, Indexer.Fetcher.Filecoin.BeryxAPI,
  base_url: ConfigHelper.parse_url_env_var("BERYX_API_BASE_URL", "https://api.zondax.ch/fil/data/v3/mainnet"),
  api_token: System.get_env("BERYX_API_TOKEN")

config :indexer, Indexer.Fetcher.Filecoin.FilfoxAPI,
  base_url: ConfigHelper.parse_url_env_var("FILFOX_API_BASE_URL", "https://filfox.info/api/v1")

config :indexer, Indexer.Fetcher.Filecoin.AddressInfo.Supervisor,
  disabled?:
    ConfigHelper.chain_type() != :filecoin or
      ConfigHelper.parse_bool_env_var("INDEXER_DISABLE_FILECOIN_ADDRESS_INFO_FETCHER")

config :indexer, Indexer.Fetcher.Filecoin.AddressInfo,
  concurrency: ConfigHelper.parse_integer_env_var("INDEXER_FILECOIN_ADDRESS_INFO_CONCURRENCY", 1)

config :indexer, Indexer.Fetcher.Scroll,
  l1_eth_get_logs_range_size: ConfigHelper.parse_integer_env_var("INDEXER_SCROLL_L1_ETH_GET_LOGS_RANGE_SIZE", 250),
  l2_eth_get_logs_range_size: ConfigHelper.parse_integer_env_var("INDEXER_SCROLL_L2_ETH_GET_LOGS_RANGE_SIZE", 1_000),
  rpc: System.get_env("INDEXER_SCROLL_L1_RPC")

config :indexer, Indexer.Fetcher.Scroll.L1FeeParam, gas_oracle: System.get_env("INDEXER_SCROLL_L2_GAS_ORACLE_CONTRACT")

config :indexer, Indexer.Fetcher.Scroll.L1FeeParam.Supervisor, disabled?: ConfigHelper.chain_type() != :scroll

config :indexer, Indexer.Fetcher.Scroll.BridgeL1,
  messenger_contract: System.get_env("INDEXER_SCROLL_L1_MESSENGER_CONTRACT"),
  start_block: ConfigHelper.parse_integer_or_nil_env_var("INDEXER_SCROLL_L1_MESSENGER_START_BLOCK")

config :indexer, Indexer.Fetcher.Scroll.BridgeL2,
  messenger_contract: System.get_env("INDEXER_SCROLL_L2_MESSENGER_CONTRACT"),
  start_block: ConfigHelper.parse_integer_env_var("INDEXER_SCROLL_L2_MESSENGER_START_BLOCK", first_block)

config :indexer, Indexer.Fetcher.Scroll.Batch,
  scroll_chain_contract: System.get_env("INDEXER_SCROLL_L1_CHAIN_CONTRACT"),
  start_block: ConfigHelper.parse_integer_or_nil_env_var("INDEXER_SCROLL_L1_BATCH_START_BLOCK"),
  eip4844_blobs_api_url: System.get_env("INDEXER_SCROLL_L1_BATCH_BLOCKSCOUT_BLOBS_API_URL", "")

config :indexer, Indexer.Fetcher.Scroll.BridgeL1.Supervisor, disabled?: ConfigHelper.chain_type() != :scroll

config :indexer, Indexer.Fetcher.Scroll.BridgeL2.Supervisor, disabled?: ConfigHelper.chain_type() != :scroll

config :indexer, Indexer.Fetcher.Scroll.Batch.Supervisor, disabled?: ConfigHelper.chain_type() != :scroll

config :indexer, Indexer.Utils.EventNotificationsCleaner,
  interval: ConfigHelper.parse_time_env_var("INDEXER_DB_EVENT_NOTIFICATIONS_CLEANUP_INTERVAL", "2m"),
  enabled:
    app_mode == :indexer && ConfigHelper.parse_bool_env_var("INDEXER_DB_EVENT_NOTIFICATIONS_CLEANUP_ENABLED", "true"),
  max_age: ConfigHelper.parse_time_env_var("INDEXER_DB_EVENT_NOTIFICATIONS_CLEANUP_MAX_AGE", "5m")

config :indexer, Indexer.Prometheus.Metrics,
  enabled: app_mode in [:indexer, :all] && ConfigHelper.parse_bool_env_var("INDEXER_METRICS_ENABLED", "true"),
  specific_metrics_enabled?: %{
    token_instances_not_uploaded_to_cdn_count:
      ConfigHelper.parse_bool_env_var("INDEXER_METRICS_ENABLED_TOKEN_INSTANCES_NOT_UPLOADED_TO_CDN_COUNT", "false"),
    failed_token_instances_metadata_count:
      ConfigHelper.parse_bool_env_var("INDEXER_METRICS_ENABLED_FAILED_TOKEN_INSTANCES_METADATA_COUNT", "true"),
    unfetched_token_instances_count:
      ConfigHelper.parse_bool_env_var("INDEXER_METRICS_ENABLED_UNFETCHED_TOKEN_INSTANCES_COUNT", "true"),
    missing_current_token_balances_count:
      ConfigHelper.parse_bool_env_var("INDEXER_METRICS_ENABLED_MISSING_CURRENT_TOKEN_BALANCES_COUNT", "true"),
    missing_archival_token_balances_count:
      ConfigHelper.parse_bool_env_var("INDEXER_METRICS_ENABLED_MISSING_ARCHIVAL_TOKEN_BALANCES_COUNT", "true")
  }

config :ex_aws,
  json_codec: Jason,
  access_key_id: System.get_env("NFT_MEDIA_HANDLER_AWS_ACCESS_KEY_ID"),
  secret_access_key: System.get_env("NFT_MEDIA_HANDLER_AWS_SECRET_ACCESS_KEY")

config :ex_aws, :s3,
  scheme: "https://",
  host: System.get_env("NFT_MEDIA_HANDLER_AWS_BUCKET_HOST"),
  port: nil,
  public_r2_url: ConfigHelper.parse_url_env_var("NFT_MEDIA_HANDLER_AWS_PUBLIC_BUCKET_URL", nil, false),
  bucket_name: System.get_env("NFT_MEDIA_HANDLER_AWS_BUCKET_NAME")

nmh_enabled? = ConfigHelper.parse_bool_env_var("NFT_MEDIA_HANDLER_ENABLED")
nmh_remote? = ConfigHelper.parse_bool_env_var("NFT_MEDIA_HANDLER_REMOTE_DISPATCHER_NODE_MODE_ENABLED")
nmh_worker? = ConfigHelper.parse_bool_env_var("NFT_MEDIA_HANDLER_IS_WORKER")

config :nft_media_handler,
  enabled?: nmh_enabled?,
  tmp_dir: "./temp",
  remote?: nmh_remote?,
  worker?: nmh_worker?,
  r2_folder: ConfigHelper.parse_path_env_var("NFT_MEDIA_HANDLER_BUCKET_FOLDER"),
  standalone_media_worker?: nmh_enabled? && nmh_remote? && nmh_worker?,
  worker_concurrency: ConfigHelper.parse_integer_env_var("NFT_MEDIA_HANDLER_WORKER_CONCURRENCY", 10),
  worker_batch_size: ConfigHelper.parse_integer_env_var("NFT_MEDIA_HANDLER_WORKER_BATCH_SIZE", 10),
  worker_spawn_tasks_timeout: ConfigHelper.parse_time_env_var("NFT_MEDIA_HANDLER_WORKER_SPAWN_TASKS_TIMEOUT", "100ms"),
  cache_uniqueness_name: :cache_uniqueness,
  cache_uniqueness_max_size: ConfigHelper.parse_integer_env_var("NFT_MEDIA_HANDLER_CACHE_UNIQUENESS_MAX_SIZE", 100_000)

config :nft_media_handler, Indexer.NFTMediaHandler.Backfiller,
  enabled?: ConfigHelper.parse_bool_env_var("NFT_MEDIA_HANDLER_BACKFILL_ENABLED"),
  queue_size: ConfigHelper.parse_integer_env_var("NFT_MEDIA_HANDLER_BACKFILL_QUEUE_SIZE", 1_000),
  enqueue_busy_waiting_timeout:
    ConfigHelper.parse_time_env_var("NFT_MEDIA_HANDLER_BACKFILL_ENQUEUE_BUSY_WAITING_TIMEOUT", "1s")

config :indexer, Indexer.Fetcher.Zilliqa.ScillaSmartContracts.Supervisor,
  disabled?: ConfigHelper.chain_type() != :zilliqa

config :indexer, Indexer.Fetcher.Zilliqa.Zrc2Tokens.Supervisor, disabled?: ConfigHelper.chain_type() != :zilliqa

config :libcluster,
  topologies: [
    k8sDNS: [
      strategy: Cluster.Strategy.Kubernetes.DNS,
      config: [
        service: System.get_env("K8S_SERVICE"),
        application_name: "blockscout"
      ]
    ]
  ]

Code.require_file("#{config_env()}.exs", "config/runtime")

for config <- "../apps/*/config/runtime/#{config_env()}.exs" |> Path.expand(__DIR__) |> Path.wildcard() do
  Code.require_file("#{config_env()}.exs", Path.dirname(config))
end
