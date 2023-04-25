import Config

[__DIR__ | ~w(config_helper.exs)]
|> Path.join()
|> Code.eval_file()

######################
### BlockScout Web ###
######################

config :block_scout_web,
  version: System.get_env("BLOCKSCOUT_VERSION"),
  release_link: System.get_env("RELEASE_LINK"),
  decompiled_smart_contract_token: System.get_env("DECOMPILED_SMART_CONTRACT_TOKEN"),
  show_percentage: ConfigHelper.parse_bool_env_var("SHOW_ADDRESS_MARKETCAP_PERCENTAGE", "true"),
  checksum_address_hashes: ConfigHelper.parse_bool_env_var("CHECKSUM_ADDRESS_HASHES", "true"),
  other_networks: System.get_env("SUPPORTED_CHAINS"),
  webapp_url: System.get_env("WEBAPP_URL"),
  api_url: System.get_env("API_URL"),
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
  show_tenderly_link: ConfigHelper.parse_bool_env_var("SHOW_TENDERLY_LINK")

config :block_scout_web, :recaptcha,
  v2_client_key: System.get_env("RE_CAPTCHA_CLIENT_KEY"),
  v2_secret_key: System.get_env("RE_CAPTCHA_SECRET_KEY"),
  v3_client_key: System.get_env("RE_CAPTCHA_V3_CLIENT_KEY"),
  v3_secret_key: System.get_env("RE_CAPTCHA_V3_SECRET_KEY")

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
  forum_link: System.get_env("FOOTER_FORUM_LINK", "https://forum.poa.network/c/blockscout"),
  github_link: System.get_env("FOOTER_GITHUB_LINK", "https://github.com/blockscout/blockscout"),
  forum_link_enabled: ConfigHelper.parse_bool_env_var("FOOTER_FORUM_LINK_ENABLED"),
  link_to_other_explorers: ConfigHelper.parse_bool_env_var("FOOTER_LINK_TO_OTHER_EXPLORERS"),
  other_explorers: System.get_env("FOOTER_OTHER_EXPLORERS", "")

config :block_scout_web, :contract,
  verification_max_libraries: ConfigHelper.parse_integer_env_var("CONTRACT_VERIFICATION_MAX_LIBRARIES", 10),
  max_length_to_show_string_without_trimming: System.get_env("CONTRACT_MAX_STRING_LENGTH_WITHOUT_TRIMMING", "2040"),
  disable_interaction: ConfigHelper.parse_bool_env_var("CONTRACT_DISABLE_INTERACTION")

default_api_rate_limit = 50

config :block_scout_web, :api_rate_limit,
  disabled: ConfigHelper.parse_bool_env_var("API_RATE_LIMIT_DISABLED"),
  global_limit: ConfigHelper.parse_integer_env_var("API_RATE_LIMIT", default_api_rate_limit),
  limit_by_key: ConfigHelper.parse_integer_env_var("API_RATE_LIMIT_BY_KEY", default_api_rate_limit),
  limit_by_whitelisted_ip:
    ConfigHelper.parse_integer_env_var("API_RATE_LIMIT_BY_WHITELISTED_IP", default_api_rate_limit),
  time_interval_limit: ConfigHelper.parse_time_env_var("API_RATE_LIMIT_TIME_INTERVAL", "1s"),
  limit_by_ip: ConfigHelper.parse_integer_env_var("API_RATE_LIMIT_BY_IP", 3000),
  time_interval_limit_by_ip: ConfigHelper.parse_time_env_var("API_RATE_LIMIT_BY_IP_TIME_INTERVAL", "5m"),
  static_api_key: System.get_env("API_RATE_LIMIT_STATIC_API_KEY"),
  whitelisted_ips: System.get_env("API_RATE_LIMIT_WHITELISTED_IPS"),
  is_blockscout_behind_proxy: ConfigHelper.parse_bool_env_var("API_RATE_LIMIT_IS_BLOCKSCOUT_BEHIND_PROXY"),
  api_v2_ui_limit: ConfigHelper.parse_integer_env_var("API_RATE_LIMIT_UI_V2_WITH_TOKEN", 5),
  api_v2_token_ttl_seconds: ConfigHelper.parse_integer_env_var("API_RATE_LIMIT_UI_V2_TOKEN_TTL_IN_SECONDS", 18000)

# Configures History
price_chart_config =
  if ConfigHelper.parse_bool_env_var("SHOW_PRICE_CHART") do
    %{market: [:price, :market_cap]}
  else
    %{}
  end

tx_chart_config =
  if ConfigHelper.parse_bool_env_var("SHOW_TXS_CHART", "true") do
    %{transactions: [:transactions_per_day]}
  else
    %{}
  end

config :block_scout_web,
  chart_config: Map.merge(price_chart_config, tx_chart_config)

config :block_scout_web, BlockScoutWeb.Chain.Address.CoinBalance,
  coin_balance_history_days: ConfigHelper.parse_integer_env_var("COIN_BALANCE_HISTORY_DAYS", 10)

config :block_scout_web, BlockScoutWeb.API.V2, enabled: ConfigHelper.parse_bool_env_var("API_V2_ENABLED")

config :block_scout_web, :account,
  authenticate_endpoint_api_key: System.get_env("ACCOUNT_AUTHENTICATE_ENDPOINT_API_KEY")

# Configures Ueberauth's Auth0 auth provider
config :ueberauth, Ueberauth.Strategy.Auth0.OAuth,
  domain: System.get_env("ACCOUNT_AUTH0_DOMAIN"),
  client_id: System.get_env("ACCOUNT_AUTH0_CLIENT_ID"),
  client_secret: System.get_env("ACCOUNT_AUTH0_CLIENT_SECRET")

# Configures Ueberauth local settings
config :ueberauth, Ueberauth, logout_url: "https://#{System.get_env("ACCOUNT_AUTH0_DOMAIN")}/v2/logout"

########################
### Ethereum JSONRPC ###
########################

config :ethereum_jsonrpc,
  rpc_transport: if(System.get_env("ETHEREUM_JSONRPC_TRANSPORT", "http") == "http", do: :http, else: :ipc),
  ipc_path: System.get_env("IPC_PATH"),
  disable_archive_balances?: ConfigHelper.parse_bool_env_var("ETHEREUM_JSONRPC_DISABLE_ARCHIVE_BALANCES")

config :ethereum_jsonrpc, EthereumJSONRPC.Geth,
  debug_trace_transaction_timeout: System.get_env("ETHEREUM_JSONRPC_DEBUG_TRACE_TRANSACTION_TIMEOUT", "5s"),
  tracer: System.get_env("INDEXER_INTERNAL_TRANSACTIONS_TRACER_TYPE", "call_tracer")

config :ethereum_jsonrpc, EthereumJSONRPC.PendingTransaction,
  type: System.get_env("ETHEREUM_JSONRPC_PENDING_TRANSACTIONS_TYPE", "default")

################
### Explorer ###
################

disable_indexer? = ConfigHelper.parse_bool_env_var("DISABLE_INDEXER")
disable_webapp? = ConfigHelper.parse_bool_env_var("DISABLE_WEBAPP")

checksum_function = System.get_env("CHECKSUM_FUNCTION")
exchange_rates_coin = System.get_env("EXCHANGE_RATES_COIN")

config :explorer,
  coin: System.get_env("COIN") || exchange_rates_coin || "ETH",
  coin_name: System.get_env("COIN_NAME") || exchange_rates_coin || "ETH",
  allowed_evm_versions:
    System.get_env("CONTRACT_VERIFICATION_ALLOWED_EVM_VERSIONS") ||
      "homestead,tangerineWhistle,spuriousDragon,byzantium,constantinople,petersburg,istanbul,berlin,london,paris,default",
  include_uncles_in_average_block_time: ConfigHelper.parse_bool_env_var("UNCLES_IN_AVERAGE_BLOCK_TIME"),
  healthy_blocks_period: ConfigHelper.parse_time_env_var("HEALTHY_BLOCKS_PERIOD", "5m"),
  realtime_events_sender:
    if(disable_webapp?,
      do: Explorer.Chain.Events.DBSender,
      else: Explorer.Chain.Events.SimpleSender
    ),
  enable_caching_implementation_data_of_proxy: true,
  avg_block_time_as_ttl_cached_implementation_data_of_proxy: true,
  fallback_ttl_cached_implementation_data_of_proxy: :timer.seconds(4),
  implementation_data_fetching_timeout: :timer.seconds(2),
  restricted_list: System.get_env("RESTRICTED_LIST"),
  restricted_list_key: System.get_env("RESTRICTED_LIST_KEY"),
  checksum_function: checksum_function && String.to_atom(checksum_function),
  elasticity_multiplier: ConfigHelper.parse_integer_env_var("EIP_1559_ELASTICITY_MULTIPLIER", 2)

config :explorer, Explorer.Chain.Events.Listener,
  enabled:
    if(disable_webapp? && disable_indexer?,
      do: false,
      else: true
    )

config :explorer, Explorer.ChainSpec.GenesisData,
  chain_spec_path: System.get_env("CHAIN_SPEC_PATH"),
  emission_format: System.get_env("EMISSION_FORMAT", "DEFAULT"),
  rewards_contract_address: System.get_env("REWARDS_CONTRACT", "0xeca443e8e1ab29971a45a9c57a6a9875701698a5")

address_sum_global_ttl = ConfigHelper.parse_time_env_var("CACHE_ADDRESS_SUM_PERIOD", "1h")

config :explorer, Explorer.Chain.Cache.AddressSum, global_ttl: address_sum_global_ttl

config :explorer, Explorer.Chain.Cache.AddressSumMinusBurnt, global_ttl: address_sum_global_ttl

config :explorer, Explorer.Chain.Cache.GasUsage,
  global_ttl: ConfigHelper.parse_time_env_var("CACHE_TOTAL_GAS_USAGE_PERIOD", "2h")

config :explorer, Explorer.Chain.Cache.Block,
  global_ttl: ConfigHelper.parse_time_env_var("CACHE_BLOCK_COUNT_PERIOD", "2h")

config :explorer, Explorer.Chain.Cache.Transaction,
  global_ttl: ConfigHelper.parse_time_env_var("CACHE_TXS_COUNT_PERIOD", "2h")

config :explorer, Explorer.Chain.Cache.GasPriceOracle,
  global_ttl: ConfigHelper.parse_time_env_var("GAS_PRICE_ORACLE_CACHE_PERIOD", "30s"),
  num_of_blocks: ConfigHelper.parse_integer_env_var("GAS_PRICE_ORACLE_NUM_OF_BLOCKS", 200),
  safelow_percentile: ConfigHelper.parse_integer_env_var("GAS_PRICE_ORACLE_SAFELOW_PERCENTILE", 35),
  average_percentile: ConfigHelper.parse_integer_env_var("GAS_PRICE_ORACLE_AVERAGE_PERCENTILE", 60),
  fast_percentile: ConfigHelper.parse_integer_env_var("GAS_PRICE_ORACLE_FAST_PERCENTILE", 90)

config :explorer, Explorer.Counters.AddressTransactionsGasUsageCounter,
  cache_period: ConfigHelper.parse_time_env_var("CACHE_ADDRESS_TRANSACTIONS_GAS_USAGE_COUNTER_PERIOD", "30m")

config :explorer, Explorer.Counters.TokenHoldersCounter,
  cache_period: ConfigHelper.parse_time_env_var("CACHE_TOKEN_HOLDERS_COUNTER_PERIOD", "1h")

config :explorer, Explorer.Counters.TokenTransfersCounter,
  cache_period: ConfigHelper.parse_time_env_var("CACHE_TOKEN_TRANSFERS_COUNTER_PERIOD", "1h")

config :explorer, Explorer.Counters.AverageBlockTime,
  enabled: true,
  period: :timer.minutes(10),
  cache_period: ConfigHelper.parse_time_env_var("CACHE_AVERAGE_BLOCK_PERIOD", "30m")

config :explorer, Explorer.Market.MarketHistoryCache,
  cache_period: ConfigHelper.parse_time_env_var("CACHE_MARKET_HISTORY_PERIOD", "6h")

config :explorer, Explorer.Counters.AddressTransactionsCounter,
  cache_period: ConfigHelper.parse_time_env_var("CACHE_ADDRESS_TRANSACTIONS_COUNTER_PERIOD", "1h")

config :explorer, Explorer.Counters.AddressTokenUsdSum,
  cache_period: ConfigHelper.parse_time_env_var("CACHE_ADDRESS_TOKENS_USD_SUM_PERIOD", "1h")

config :explorer, Explorer.Counters.AddressTokenTransfersCounter,
  cache_period: ConfigHelper.parse_time_env_var("CACHE_ADDRESS_TOKEN_TRANSFERS_COUNTER_PERIOD", "1h")

config :explorer, Explorer.ExchangeRates,
  store: :ets,
  enabled: !ConfigHelper.parse_bool_env_var("DISABLE_EXCHANGE_RATES"),
  fetch_btc_value: ConfigHelper.parse_bool_env_var("EXCHANGE_RATES_FETCH_BTC_VALUE")

config :explorer, Explorer.ExchangeRates.Source, source: ConfigHelper.exchange_rates_source()

config :explorer, Explorer.ExchangeRates.Source.CoinMarketCap,
  api_key: System.get_env("EXCHANGE_RATES_COINMARKETCAP_API_KEY")

config :explorer, Explorer.ExchangeRates.Source.CoinGecko,
  platform: System.get_env("EXCHANGE_RATES_COINGECKO_PLATFORM_ID"),
  api_key: System.get_env("EXCHANGE_RATES_COINGECKO_API_KEY"),
  coin_id: System.get_env("EXCHANGE_RATES_COINGECKO_COIN_ID")

config :explorer, Explorer.ExchangeRates.TokenExchangeRates,
  enabled: !ConfigHelper.parse_bool_env_var("DISABLE_TOKEN_EXCHANGE_RATE", "true"),
  interval: ConfigHelper.parse_time_env_var("TOKEN_EXCHANGE_RATE_INTERVAL", "5s"),
  refetch_interval: ConfigHelper.parse_time_env_var("TOKEN_EXCHANGE_RATE_REFETCH_INTERVAL", "1h"),
  max_batch_size: ConfigHelper.parse_integer_env_var("TOKEN_EXCHANGE_RATE_MAX_BATCH_SIZE", 150)

config :explorer, Explorer.Market.History.Cataloger, enabled: !disable_indexer?

config :explorer, Explorer.Chain.Transaction.History.Historian,
  enabled: ConfigHelper.parse_bool_env_var("TXS_STATS_ENABLED", "true"),
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
  ttl_check_interval: ConfigHelper.cache_ttl_check_interval(disable_indexer?),
  global_ttl: ConfigHelper.cache_global_ttl(disable_indexer?)

config :explorer, Explorer.Chain.Cache.Transactions,
  ttl_check_interval: ConfigHelper.cache_ttl_check_interval(disable_indexer?),
  global_ttl: ConfigHelper.cache_global_ttl(disable_indexer?)

config :explorer, Explorer.Chain.Cache.TransactionsApiV2,
  ttl_check_interval: ConfigHelper.cache_ttl_check_interval(disable_indexer?),
  global_ttl: ConfigHelper.cache_global_ttl(disable_indexer?)

config :explorer, Explorer.Chain.Cache.Accounts,
  ttl_check_interval: ConfigHelper.cache_ttl_check_interval(disable_indexer?),
  global_ttl: ConfigHelper.cache_global_ttl(disable_indexer?)

config :explorer, Explorer.Chain.Cache.Uncles,
  ttl_check_interval: ConfigHelper.cache_ttl_check_interval(disable_indexer?),
  global_ttl: ConfigHelper.cache_global_ttl(disable_indexer?)

config :explorer, Explorer.ThirdPartyIntegrations.Sourcify,
  server_url: System.get_env("SOURCIFY_SERVER_URL") || "https://sourcify.dev/server",
  enabled: ConfigHelper.parse_bool_env_var("SOURCIFY_INTEGRATION_ENABLED"),
  chain_id: System.get_env("CHAIN_ID"),
  repo_url: System.get_env("SOURCIFY_REPO_URL") || "https://repo.sourcify.dev/contracts"

config :explorer, Explorer.SmartContract.RustVerifierInterfaceBehaviour,
  service_url: System.get_env("MICROSERVICE_SC_VERIFIER_URL"),
  enabled: ConfigHelper.parse_bool_env_var("MICROSERVICE_SC_VERIFIER_ENABLED"),
  # or "eth_bytecode_db"
  type: System.get_env("MICROSERVICE_SC_VERIFIER_TYPE", "sc_verifier")

config :explorer, Explorer.Visualize.Sol2uml,
  service_url: System.get_env("MICROSERVICE_VISUALIZE_SOL2UML_URL"),
  enabled: ConfigHelper.parse_bool_env_var("MICROSERVICE_VISUALIZE_SOL2UML_ENABLED")

config :explorer, Explorer.SmartContract.SigProviderInterface,
  service_url: System.get_env("MICROSERVICE_SIG_PROVIDER_URL"),
  enabled: ConfigHelper.parse_bool_env_var("MICROSERVICE_SIG_PROVIDER_ENABLED")

config :explorer, Explorer.ThirdPartyIntegrations.AirTable,
  table_url: System.get_env("ACCOUNT_PUBLIC_TAGS_AIRTABLE_URL"),
  api_key: System.get_env("ACCOUNT_PUBLIC_TAGS_AIRTABLE_API_KEY")

config :explorer, Explorer.Mailer,
  adapter: Bamboo.SendGridAdapter,
  api_key: System.get_env("ACCOUNT_SENDGRID_API_KEY")

config :explorer, Explorer.Account,
  enabled: ConfigHelper.parse_bool_env_var("ACCOUNT_ENABLED"),
  sendgrid: [
    sender: System.get_env("ACCOUNT_SENDGRID_SENDER"),
    template: System.get_env("ACCOUNT_SENDGRID_TEMPLATE")
  ]

config :explorer, :token_id_migration,
  first_block: ConfigHelper.parse_integer_env_var("TOKEN_ID_MIGRATION_FIRST_BLOCK", 0),
  concurrency: ConfigHelper.parse_integer_env_var("TOKEN_ID_MIGRATION_CONCURRENCY", 1),
  batch_size: ConfigHelper.parse_integer_env_var("TOKEN_ID_MIGRATION_BATCH_SIZE", 500)

config :explorer, Explorer.Chain.Cache.MinMissingBlockNumber,
  batch_size: ConfigHelper.parse_integer_env_var("MIN_MISSING_BLOCK_NUMBER_BATCH_SIZE", 100_000)

config :explorer, :spandex,
  batch_size: ConfigHelper.parse_integer_env_var("SPANDEX_BATCH_SIZE", 100),
  sync_threshold: ConfigHelper.parse_integer_env_var("SPANDEX_SYNC_THRESHOLD", 100)

config :explorer, :datadog, port: ConfigHelper.parse_integer_env_var("DATADOG_PORT", 8126)

config :explorer, Explorer.Chain.Cache.TransactionActionTokensData,
  max_cache_size: ConfigHelper.parse_integer_env_var("INDEXER_TX_ACTIONS_MAX_TOKEN_CACHE_SIZE", 100_000)

config :explorer, Explorer.Chain.Fetcher.LookUpSmartContractSourcesOnDemand,
  fetch_interval:
    ConfigHelper.parse_time_env_var("MICROSERVICE_MICROSERVICE_ETH_BYTECODE_DB_INTERVAL_BETWEEN_LOOKUPS", "10m")

###############
### Indexer ###
###############

config :indexer,
  block_transformer: ConfigHelper.block_transformer(),
  metadata_updater_milliseconds_interval: ConfigHelper.parse_time_env_var("TOKEN_METADATA_UPDATE_INTERVAL", "48h"),
  block_ranges: System.get_env("BLOCK_RANGES"),
  first_block: System.get_env("FIRST_BLOCK") || "",
  last_block: System.get_env("LAST_BLOCK") || "",
  trace_first_block: System.get_env("TRACE_FIRST_BLOCK") || "",
  trace_last_block: System.get_env("TRACE_LAST_BLOCK") || "",
  fetch_rewards_way: System.get_env("FETCH_REWARDS_WAY", "trace_block"),
  memory_limit: ConfigHelper.indexer_memory_limit(),
  receipts_batch_size: ConfigHelper.parse_integer_env_var("INDEXER_RECEIPTS_BATCH_SIZE", 250),
  receipts_concurrency: ConfigHelper.parse_integer_env_var("INDEXER_RECEIPTS_CONCURRENCY", 10)

config :indexer, Indexer.Supervisor, enabled: !ConfigHelper.parse_bool_env_var("DISABLE_INDEXER")

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

config :indexer, Indexer.Fetcher.PendingTransaction.Supervisor,
  disabled?:
    System.get_env("ETHEREUM_JSONRPC_VARIANT") == "besu" ||
      ConfigHelper.parse_bool_env_var("INDEXER_DISABLE_PENDING_TRANSACTIONS_FETCHER")

config :indexer, Indexer.Fetcher.TokenBalanceOnDemand,
  threshold: ConfigHelper.parse_time_env_var("TOKEN_BALANCE_ON_DEMAND_FETCHER_THRESHOLD", "1h"),
  fallback_threshold_in_blocks: 500

config :indexer, Indexer.Fetcher.CoinBalanceOnDemand,
  threshold: ConfigHelper.parse_time_env_var("COIN_BALANCE_ON_DEMAND_FETCHER_THRESHOLD", "1h"),
  fallback_threshold_in_blocks: 500

config :indexer, Indexer.Fetcher.BlockReward.Supervisor,
  disabled?: ConfigHelper.parse_bool_env_var("INDEXER_DISABLE_BLOCK_REWARD_FETCHER")

config :indexer, Indexer.Fetcher.InternalTransaction.Supervisor,
  disabled?: ConfigHelper.parse_bool_env_var("INDEXER_DISABLE_INTERNAL_TRANSACTIONS_FETCHER")

config :indexer, Indexer.Fetcher.CoinBalance.Supervisor,
  disabled?: ConfigHelper.parse_bool_env_var("INDEXER_DISABLE_ADDRESS_COIN_BALANCE_FETCHER")

config :indexer, Indexer.Fetcher.TokenUpdater.Supervisor,
  disabled?: ConfigHelper.parse_bool_env_var("INDEXER_DISABLE_CATALOGED_TOKEN_UPDATER_FETCHER")

config :indexer, Indexer.Fetcher.EmptyBlocksSanitizer.Supervisor,
  disabled?: ConfigHelper.parse_bool_env_var("INDEXER_DISABLE_EMPTY_BLOCKS_SANITIZER")

config :indexer, Indexer.Block.Realtime.Supervisor,
  enabled: !ConfigHelper.parse_bool_env_var("DISABLE_REALTIME_INDEXER")

config :indexer, Indexer.Fetcher.TokenInstance.Realtime.Supervisor,
  disabled?: ConfigHelper.parse_bool_env_var("INDEXER_DISABLE_TOKEN_INSTANCE_REALTIME_FETCHER")

config :indexer, Indexer.Fetcher.TokenInstance.Retry.Supervisor,
  disabled?: ConfigHelper.parse_bool_env_var("INDEXER_DISABLE_TOKEN_INSTANCE_RETRY_FETCHER")

config :indexer, Indexer.Fetcher.TokenInstance.Sanitize.Supervisor,
  disabled?: ConfigHelper.parse_bool_env_var("INDEXER_DISABLE_TOKEN_INSTANCE_SANITIZE_FETCHER")

config :indexer, Indexer.Fetcher.EmptyBlocksSanitizer,
  batch_size: ConfigHelper.parse_integer_env_var("INDEXER_EMPTY_BLOCKS_SANITIZER_BATCH_SIZE", 100)

config :indexer, Indexer.Block.Catchup.MissingRangesCollector,
  batch_size: ConfigHelper.parse_integer_env_var("INDEXER_CATCHUP_MISSING_RANGES_BATCH_SIZE", 100_000)

config :indexer, Indexer.Block.Catchup.Fetcher,
  batch_size: ConfigHelper.parse_integer_env_var("INDEXER_CATCHUP_BLOCKS_BATCH_SIZE", 10),
  concurrency: ConfigHelper.parse_integer_env_var("INDEXER_CATCHUP_BLOCKS_CONCURRENCY", 10)

config :indexer, Indexer.Fetcher.BlockReward,
  batch_size: ConfigHelper.parse_integer_env_var("INDEXER_BLOCK_REWARD_BATCH_SIZE", 10),
  concurrency: ConfigHelper.parse_integer_env_var("INDEXER_BLOCK_REWARD_CONCURRENCY", 4)

config :indexer, Indexer.Fetcher.TokenInstance.Retry,
  concurrency: ConfigHelper.parse_integer_env_var("INDEXER_TOKEN_INSTANCE_RETRY_CONCURRENCY", 10),
  refetch_interval: ConfigHelper.parse_time_env_var("INDEXER_TOKEN_INSTANCE_RETRY_REFETCH_INTERVAL", "24h")

config :indexer, Indexer.Fetcher.TokenInstance.Realtime,
  concurrency: ConfigHelper.parse_integer_env_var("INDEXER_TOKEN_INSTANCE_REALTIME_CONCURRENCY", 10)

config :indexer, Indexer.Fetcher.TokenInstance.Sanitize,
  concurrency: ConfigHelper.parse_integer_env_var("INDEXER_TOKEN_INSTANCE_SANITIZE_CONCURRENCY", 10)

config :indexer, Indexer.Fetcher.InternalTransaction,
  batch_size: ConfigHelper.parse_integer_env_var("INDEXER_INTERNAL_TRANSACTIONS_BATCH_SIZE", 10),
  concurrency: ConfigHelper.parse_integer_env_var("INDEXER_INTERNAL_TRANSACTIONS_CONCURRENCY", 4)

config :indexer, Indexer.Fetcher.CoinBalance,
  batch_size: ConfigHelper.parse_integer_env_var("INDEXER_COIN_BALANCES_BATCH_SIZE", 500),
  concurrency: ConfigHelper.parse_integer_env_var("INDEXER_COIN_BALANCES_CONCURRENCY", 4)

Code.require_file("#{config_env()}.exs", "config/runtime")

for config <- "../apps/*/config/runtime/#{config_env()}.exs" |> Path.expand(__DIR__) |> Path.wildcard() do
  Code.require_file("#{config_env()}.exs", Path.dirname(config))
end
