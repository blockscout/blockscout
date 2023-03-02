import Config

import Bitwise

indexer_memory_limit_default = 1

indexer_memory_limit =
  "INDEXER_MEMORY_LIMIT"
  |> System.get_env(to_string(indexer_memory_limit_default))
  |> String.downcase()
  |> Integer.parse()
  |> case do
    {integer, g} when g in ["g", "gb", ""] -> integer <<< 30
    {integer, m} when m in ["m", "mb"] -> integer <<< 20
    _ -> indexer_memory_limit_default <<< 30
  end

config :indexer,
  memory_limit: indexer_memory_limit

indexer_empty_blocks_sanitizer_batch_size_default = 100

indexer_empty_blocks_sanitizer_batch_size =
  "INDEXER_EMPTY_BLOCKS_SANITIZER_BATCH_SIZE"
  |> System.get_env(to_string(indexer_empty_blocks_sanitizer_batch_size_default))
  |> Integer.parse()
  |> case do
    {integer, ""} -> integer
    _ -> indexer_empty_blocks_sanitizer_batch_size_default
  end

config :indexer, Indexer.Fetcher.EmptyBlocksSanitizer, batch_size: indexer_empty_blocks_sanitizer_batch_size

######################
### BlockScout Web ###
######################

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
  url: [
    path: network_path
  ],
  render_errors: [view: BlockScoutWeb.ErrorView, accepts: ~w(html json)],
  pubsub_server: BlockScoutWeb.PubSub

config :block_scout_web, :footer,
  chat_link: System.get_env("FOOTER_CHAT_LINK", "https://discord.gg/blockscout"),
  forum_link: System.get_env("FOOTER_FORUM_LINK", "https://forum.poa.network/c/blockscout"),
  github_link: System.get_env("FOOTER_GITHUB_LINK", "https://github.com/blockscout/blockscout"),
  enable_forum_link: System.get_env("FOOTER_ENABLE_FORUM_LINK", "false") == "true"

# Configures Ueberauth's Auth0 auth provider
config :ueberauth, Ueberauth.Strategy.Auth0.OAuth,
  domain: System.get_env("ACCOUNT_AUTH0_DOMAIN"),
  client_id: System.get_env("ACCOUNT_AUTH0_CLIENT_ID"),
  client_secret: System.get_env("ACCOUNT_AUTH0_CLIENT_SECRET")

# Configures Ueberauth local settings
config :ueberauth, Ueberauth,
  logout_url: System.get_env("ACCOUNT_AUTH0_LOGOUT_URL"),
  logout_return_to_url: System.get_env("ACCOUNT_AUTH0_LOGOUT_RETURN_URL")

config :block_scout_web,
  version: System.get_env("BLOCKSCOUT_VERSION"),
  release_link: System.get_env("RELEASE_LINK"),
  decompiled_smart_contract_token: System.get_env("DECOMPILED_SMART_CONTRACT_TOKEN"),
  show_percentage: if(System.get_env("SHOW_ADDRESS_MARKETCAP_PERCENTAGE", "true") == "false", do: false, else: true),
  checksum_address_hashes: if(System.get_env("CHECKSUM_ADDRESS_HASHES", "true") == "false", do: false, else: true)

config :block_scout_web, BlockScoutWeb.Chain,
  network: System.get_env("NETWORK"),
  subnetwork: System.get_env("SUBNETWORK"),
  network_icon: System.get_env("NETWORK_ICON"),
  logo: System.get_env("LOGO"),
  logo_footer: System.get_env("LOGO_FOOTER"),
  logo_text: System.get_env("LOGO_TEXT"),
  has_emission_funds: false,
  staking_enabled: not is_nil(System.get_env("POS_STAKING_CONTRACT")),
  staking_enabled_in_menu: System.get_env("ENABLE_POS_STAKING_IN_MENU", "false") == "true",
  show_staking_warning: System.get_env("SHOW_STAKING_WARNING", "false") == "true",
  show_maintenance_alert: System.get_env("SHOW_MAINTENANCE_ALERT", "false") == "true",
  # how often (in blocks) the list of pools should autorefresh in UI (zero turns off autorefreshing)
  staking_pool_list_refresh_interval: 5,
  enable_testnet_label: System.get_env("SHOW_TESTNET_LABEL", "false") == "true",
  testnet_label_text: System.get_env("TESTNET_LABEL_TEXT", "Testnet")

verification_max_libraries_default = 10

verification_max_libraries =
  "CONTRACT_VERIFICATION_MAX_LIBRARIES"
  |> System.get_env(to_string(verification_max_libraries_default))
  |> Integer.parse()
  |> case do
    {integer, ""} -> integer
    _ -> verification_max_libraries_default
  end

config :block_scout_web,
  link_to_other_explorers: System.get_env("LINK_TO_OTHER_EXPLORERS") == "true",
  other_explorers: System.get_env("OTHER_EXPLORERS"),
  bridges: System.get_env("BRIDGES"),
  other_bridges: System.get_env("OTHER_BRIDGES"),
  bridges_alm: System.get_env("BRIDGES_ALM"),
  defi: System.get_env("DEFI_MENU_LIST"),
  nft: System.get_env("NFT_MENU_LIST"),
  other_networks: System.get_env("SUPPORTED_CHAINS"),
  webapp_url: System.get_env("WEBAPP_URL"),
  api_url: System.get_env("API_URL"),
  apps_menu: if(System.get_env("APPS_MENU", "false") == "true", do: true, else: false),
  apps: System.get_env("APPS") || System.get_env("EXTERNAL_APPS"),
  moon_token_addresses: System.get_env("MOON_TOKEN_ADDRESSES"),
  bricks_token_addresses: System.get_env("BRICKS_TOKEN_ADDRESSES"),
  eth_omni_bridge_mediator: System.get_env("ETH_OMNI_BRIDGE_MEDIATOR"),
  bsc_omni_bridge_mediator: System.get_env("BSC_OMNI_BRIDGE_MEDIATOR"),
  poa_omni_bridge_mediator: System.get_env("POA_OMNI_BRIDGE_MEDIATOR"),
  amb_bridge_mediators: System.get_env("AMB_BRIDGE_MEDIATORS"),
  foreign_json_rpc: System.get_env("FOREIGN_JSON_RPC", ""),
  gas_price: System.get_env("GAS_PRICE", nil),
  dark_forest_addresses: System.get_env("CUSTOM_CONTRACT_ADDRESSES_DARK_FOREST"),
  dark_forest_addresses_v_0_5: System.get_env("CUSTOM_CONTRACT_ADDRESSES_DARK_FOREST_0_5"),
  dark_forest_addresses_v_0_6: System.get_env("CUSTOM_CONTRACT_ADDRESSES_DARK_FOREST_0_6"),
  dark_forest_addresses_v_0_6_r2: System.get_env("CUSTOM_CONTRACT_ADDRESSES_DARK_FOREST_0_6_R2"),
  dark_forest_addresses_v_0_6_r3: System.get_env("CUSTOM_CONTRACT_ADDRESSES_DARK_FOREST_0_6_R3"),
  dark_forest_addresses_v_0_6_r4: System.get_env("CUSTOM_CONTRACT_ADDRESSES_DARK_FOREST_0_6_R4"),
  dark_forest_addresses_v_0_6_r5: System.get_env("CUSTOM_CONTRACT_ADDRESSES_DARK_FOREST_0_6_R5"),
  dark_forest_addresses_dao: System.get_env("CUSTOM_CONTRACT_ADDRESSES_DARK_FOREST_DAO"),
  circles_addresses: System.get_env("CUSTOM_CONTRACT_ADDRESSES_CIRCLES"),
  test_tokens_addresses: System.get_env("CUSTOM_CONTRACT_ADDRESSES_TEST_TOKEN"),
  max_size_to_show_array_as_is: Integer.parse(System.get_env("MAX_SIZE_UNLESS_HIDE_ARRAY", "50")),
  max_length_to_show_string_without_trimming: System.get_env("MAX_STRING_LENGTH_WITHOUT_TRIMMING", "2040"),
  gts_addresses: System.get_env("CUSTOM_CONTRACT_ADDRESSES_GTGS_TOKEN"),
  chainlink_oracles: System.get_env("CUSTOM_CONTRACT_ADDRESSES_CHAINLINK_ORACLES"),
  re_captcha_secret_key: System.get_env("RE_CAPTCHA_SECRET_KEY", nil),
  re_captcha_client_key: System.get_env("RE_CAPTCHA_CLIENT_KEY", nil),
  new_tags: System.get_env("NEW_TAGS"),
  chain_id: System.get_env("CHAIN_ID"),
  json_rpc: System.get_env("JSON_RPC"),
  alert_to_addresses: System.get_env("ALERT_TO_ADDRESSES"),
  disable_add_to_mm_button: System.get_env("DISABLE_ADD_TO_MM_BUTTON", "false") == "true",
  verification_max_libraries: verification_max_libraries,
  permanent_dark_mode_enabled: System.get_env("PERMANENT_DARK_MODE_ENABLED", "false") == "true",
  permanent_light_mode_enabled: System.get_env("PERMANENT_LIGHT_MODE_ENABLED", "false") == "true"

config :block_scout_web, :gas_tracker,
  enabled: System.get_env("GAS_TRACKER_ENABLED", "false") == "true",
  enabled_in_menu: System.get_env("GAS_TRACKER_ENABLED_IN_MENU", "false") == "true",
  access_token: System.get_env("GAS_TRACKER_ACCESS_KEY", nil)

default_api_rate_limit = 50
default_api_rate_limit_str = Integer.to_string(default_api_rate_limit)

global_api_rate_limit_value =
  "API_RATE_LIMIT"
  |> System.get_env(default_api_rate_limit_str)
  |> Integer.parse()
  |> case do
    {integer, ""} -> integer
    _ -> default_api_rate_limit
  end

api_rate_limit_by_key_value =
  "API_RATE_LIMIT_BY_KEY"
  |> System.get_env(default_api_rate_limit_str)
  |> Integer.parse()
  |> case do
    {integer, ""} -> integer
    _ -> default_api_rate_limit
  end

api_rate_limit_by_ip_value =
  "API_RATE_LIMIT_BY_IP"
  |> System.get_env(default_api_rate_limit_str)
  |> Integer.parse()
  |> case do
    {integer, ""} -> integer
    _ -> default_api_rate_limit
  end

config :block_scout_web, :api_rate_limit,
  disabled: System.get_env("API_RATE_LIMIT_DISABLED", "false") == "true",
  global_limit: global_api_rate_limit_value,
  limit_by_key: api_rate_limit_by_key_value,
  limit_by_ip: api_rate_limit_by_ip_value,
  static_api_key: System.get_env("API_RATE_LIMIT_STATIC_API_KEY", nil),
  whitelisted_ips: System.get_env("API_RATE_LIMIT_WHITELISTED_IPS", nil)

config :block_scout_web, BlockScoutWeb.Endpoint,
  server: true,
  url: [
    scheme: System.get_env("BLOCKSCOUT_PROTOCOL") || "http",
    host: System.get_env("BLOCKSCOUT_HOST") || "localhost"
  ]

# Configures History
price_chart_config =
  if System.get_env("SHOW_PRICE_CHART", "false") != "false" do
    %{market: [:price, :market_cap]}
  else
    %{}
  end

tx_chart_config =
  if System.get_env("SHOW_TXS_CHART", "true") == "true" do
    %{transactions: [:transactions_per_day]}
  else
    %{}
  end

gas_usage_chart_config =
  if System.get_env("GAS_TRACKER_ENABLED", "false") == "true" do
    %{gas_usage: [:gas_usage_per_day]}
  else
    %{}
  end

config :block_scout_web,
  chart_config: Map.merge(price_chart_config, tx_chart_config)

config :block_scout_web,
  gas_usage_chart_config: gas_usage_chart_config

config :block_scout_web, BlockScoutWeb.Chain.GasUsageHistoryChartController,
  # days
  history_size: 60

config :block_scout_web, BlockScoutWeb.Chain.Address.CoinBalance,
  # days
  coin_balance_history_days: System.get_env("COIN_BALANCE_HISTORY_DAYS", "10")

config :block_scout_web, BlockScoutWeb.API.V2, enabled: System.get_env("API_V2_ENABLED") == "true"

########################
### Ethereum JSONRPC ###
########################

config :ethereum_jsonrpc,
  rpc_transport: if(System.get_env("ETHEREUM_JSONRPC_TRANSPORT", "http") == "http", do: :http, else: :ipc),
  ipc_path: System.get_env("IPC_PATH"),
  disable_archive_balances?: System.get_env("ETHEREUM_JSONRPC_DISABLE_ARCHIVE_BALANCES", "false") == "true"

debug_trace_transaction_timeout = System.get_env("ETHEREUM_JSONRPC_DEBUG_TRACE_TRANSACTION_TIMEOUT", "5s")

config :ethereum_jsonrpc, EthereumJSONRPC.Geth,
  debug_trace_transaction_timeout: debug_trace_transaction_timeout,
  tracer: System.get_env("INDEXER_INTERNAL_TRANSACTIONS_TRACER_TYPE", "call_tracer")

config :ethereum_jsonrpc, EthereumJSONRPC.PendingTransaction,
  type: System.get_env("ETHEREUM_JSONRPC_PENDING_TRANSACTIONS_TYPE", "default")

################
### Explorer ###
################

disable_indexer = System.get_env("DISABLE_INDEXER")
disable_webapp = System.get_env("DISABLE_WEBAPP")

healthy_blocks_period =
  System.get_env("HEALTHY_BLOCKS_PERIOD", "5")
  |> Integer.parse()
  |> elem(0)
  |> :timer.minutes()

config :explorer,
  coin: System.get_env("COIN", nil) || System.get_env("EXCHANGE_RATES_COIN") || "ETH",
  coin_name: System.get_env("COIN_NAME", nil) || System.get_env("EXCHANGE_RATES_COIN") || "ETH",
  allowed_evm_versions:
    System.get_env("ALLOWED_EVM_VERSIONS") ||
      "homestead,tangerineWhistle,spuriousDragon,byzantium,constantinople,petersburg,istanbul,berlin,london,default",
  include_uncles_in_average_block_time:
    if(System.get_env("UNCLES_IN_AVERAGE_BLOCK_TIME") == "true", do: true, else: false),
  healthy_blocks_period: healthy_blocks_period,
  realtime_events_sender:
    if(disable_webapp != "true",
      do: Explorer.Chain.Events.SimpleSender,
      else: Explorer.Chain.Events.DBSender
    ),
  enable_caching_implementation_data_of_proxy: true,
  avg_block_time_as_ttl_cached_implementation_data_of_proxy: true,
  fallback_ttl_cached_implementation_data_of_proxy: :timer.seconds(4),
  implementation_data_fetching_timeout: :timer.seconds(2),
  restricted_list: System.get_env("RESTRICTED_LIST", nil),
  restricted_list_key: System.get_env("RESTRICTED_LIST_KEY", nil)

config :explorer, Explorer.Chain.Events.Listener,
  enabled:
    if(disable_webapp == "true" && disable_indexer == "true",
      do: false,
      else: true
    )

config :explorer, Explorer.ChainSpec.GenesisData,
  chain_spec_path: System.get_env("CHAIN_SPEC_PATH"),
  emission_format: System.get_env("EMISSION_FORMAT", "DEFAULT"),
  rewards_contract_address: System.get_env("REWARDS_CONTRACT", "0xeca443e8e1ab29971a45a9c57a6a9875701698a5")

config :explorer, Explorer.Chain.Cache.BlockNumber,
  ttl_check_interval: if(disable_indexer == "true", do: :timer.seconds(1), else: false),
  global_ttl: if(disable_indexer == "true", do: :timer.seconds(5))

address_sum_global_ttl =
  "CACHE_ADDRESS_SUM_PERIOD"
  |> System.get_env("")
  |> Integer.parse()
  |> case do
    {integer, ""} -> integer
    _ -> 3600
  end
  |> :timer.seconds()

config :explorer, Explorer.Chain.Cache.AddressSum, global_ttl: address_sum_global_ttl

config :explorer, Explorer.Chain.Cache.AddressSumMinusBurnt, global_ttl: address_sum_global_ttl

config :explorer, Explorer.Counters.Bridge,
  enabled: if(System.get_env("SUPPLY_MODULE") === "TokenBridge", do: true, else: false),
  disable_lp_tokens_in_market_cap: System.get_env("DISABLE_LP_TOKENS_IN_MARKET_CAP") == "true"

block_count_global_ttl =
  "CACHE_BLOCK_COUNT_PERIOD"
  |> System.get_env("")
  |> Integer.parse()
  |> case do
    {integer, ""} -> integer
    _ -> 7200
  end
  |> :timer.seconds()

config :explorer, Explorer.Chain.Cache.Block, global_ttl: block_count_global_ttl

transaction_count_global_ttl =
  "CACHE_TXS_COUNT_PERIOD"
  |> System.get_env("")
  |> Integer.parse()
  |> case do
    {integer, ""} -> integer
    _ -> 7200
  end
  |> :timer.seconds()

config :explorer, Explorer.Chain.Cache.Transaction, global_ttl: transaction_count_global_ttl

gas_price_oracle_global_ttl =
  "GAS_PRICE_ORACLE_CACHE_PERIOD"
  |> System.get_env("")
  |> Integer.parse()
  |> case do
    {integer, ""} -> integer
    _ -> 30
  end
  |> :timer.seconds()

config :explorer, Explorer.Chain.Cache.GasPriceOracle, global_ttl: gas_price_oracle_global_ttl

config :explorer, Explorer.ExchangeRates,
  store: :ets,
  enabled: System.get_env("DISABLE_EXCHANGE_RATES") != "true",
  coingecko_coin_id: System.get_env("EXCHANGE_RATES_COINGECKO_COIN_ID"),
  coingecko_api_key: System.get_env("EXCHANGE_RATES_COINGECKO_API_KEY"),
  coinmarketcap_api_key: System.get_env("EXCHANGE_RATES_COINMARKETCAP_API_KEY"),
  fetch_btc_value: System.get_env("EXCHANGE_RATES_FETCH_BTC_VALUE") == "true"

exchange_rates_source =
  cond do
    System.get_env("EXCHANGE_RATES_SOURCE") == "token_bridge" -> Explorer.ExchangeRates.Source.TokenBridge
    System.get_env("EXCHANGE_RATES_SOURCE") == "coin_gecko" -> Explorer.ExchangeRates.Source.CoinGecko
    System.get_env("EXCHANGE_RATES_SOURCE") == "coin_market_cap" -> Explorer.ExchangeRates.Source.CoinMarketCap
    true -> Explorer.ExchangeRates.Source.CoinGecko
  end

config :explorer, Explorer.ExchangeRates.Source, source: exchange_rates_source

config :explorer, Explorer.KnownTokens, enabled: System.get_env("DISABLE_KNOWN_TOKENS") != "true", store: :ets

config :explorer, Explorer.Market.History.Cataloger, enabled: disable_indexer != "true"

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
  enabled: System.get_env("ENABLE_TXS_STATS", "true") != "false",
  init_lag: txs_stats_init_lag,
  days_to_compile_at_init: txs_stats_days_to_compile_at_init

history_fetch_interval =
  case Integer.parse(System.get_env("HISTORY_FETCH_INTERVAL", "")) do
    {mins, ""} -> mins
    _ -> 60
  end
  |> :timer.minutes()

config :explorer, Explorer.History.Process, history_fetch_interval: history_fetch_interval

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
  checksum_function: System.get_env("CHECKSUM_FUNCTION") && String.to_atom(System.get_env("CHECKSUM_FUNCTION"))

config :explorer, Explorer.Chain.Cache.Blocks,
  ttl_check_interval: if(disable_indexer == "true", do: :timer.seconds(1), else: false),
  global_ttl: if(disable_indexer == "true", do: :timer.seconds(5))

config :explorer, Explorer.Chain.Cache.Transactions,
  ttl_check_interval: if(disable_indexer == "true", do: :timer.seconds(1), else: false),
  global_ttl: if(disable_indexer == "true", do: :timer.seconds(5))

config :explorer, Explorer.Chain.Cache.TransactionsApiV2,
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

config :explorer, Explorer.ThirdPartyIntegrations.AirTable,
  table_url: System.get_env("PUBLIC_TAGS_AIRTABLE_URL"),
  api_key: System.get_env("PUBLIC_TAGS_AIRTABLE_API_KEY")

config :explorer, Explorer.Mailer,
  adapter: Bamboo.SendGridAdapter,
  api_key: System.get_env("SENDGRID_API_KEY")

config :explorer, Explorer.Account,
  sendgrid: [
    sender: System.get_env("SENDGRID_SENDER"),
    template: System.get_env("SENDGRID_TEMPLATE")
  ]

config :explorer, Explorer.SmartContract.RustVerifierInterface,
  service_url: System.get_env("RUST_VERIFICATION_SERVICE_URL"),
  enabled: System.get_env("ENABLE_RUST_VERIFICATION_SERVICE") == "true"

config :explorer, Explorer.Visualize.Sol2uml,
  service_url: System.get_env("VISUALIZE_SOL2UML_SERVICE_URL"),
  enabled: System.get_env("VISUALIZE_SOL2UML_ENABLED") == "true"

config :explorer, Explorer.SmartContract.SigProviderInterface,
  service_url: System.get_env("SIG_PROVIDER_SERVICE_URL"),
  enabled: System.get_env("SIG_PROVIDER_ENABLED") == "true"

config :explorer, Explorer.ThirdPartyIntegrations.AirTable,
  table_url: System.get_env("ACCOUNT_PUBLIC_TAGS_AIRTABLE_URL"),
  api_key: System.get_env("ACCOUNT_PUBLIC_TAGS_AIRTABLE_API_KEY")

config :explorer, Explorer.Mailer,
  adapter: Bamboo.SendGridAdapter,
  api_key: System.get_env("ACCOUNT_SENDGRID_API_KEY")

config :explorer, Explorer.Account,
  enabled: System.get_env("ACCOUNT_ENABLED") == "true",
  sendgrid: [
    sender: System.get_env("ACCOUNT_SENDGRID_SENDER"),
    template: System.get_env("ACCOUNT_SENDGRID_TEMPLATE")
  ]

{token_id_migration_first_block, _} = Integer.parse(System.get_env("TOKEN_ID_MIGRATION_FIRST_BLOCK", "0"))
{token_id_migration_concurrency, _} = Integer.parse(System.get_env("TOKEN_ID_MIGRATION_CONCURRENCY", "1"))
{token_id_migration_batch_size, _} = Integer.parse(System.get_env("TOKEN_ID_MIGRATION_BATCH_SIZE", "500"))

config :explorer, :token_id_migration,
  first_block: token_id_migration_first_block,
  concurrency: token_id_migration_concurrency,
  batch_size: token_id_migration_batch_size

min_missing_block_number_batch_size_default_str = "100000"

{min_missing_block_number_batch_size, _} =
  Integer.parse(System.get_env("MIN_MISSING_BLOCK_NUMBER_BATCH_SIZE", min_missing_block_number_batch_size_default_str))

config :explorer, Explorer.Chain.Cache.MinMissingBlockNumber, batch_size: min_missing_block_number_batch_size

###############
### Indexer ###
###############

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
  metadata_updater_seconds_interval:
    String.to_integer(System.get_env("TOKEN_METADATA_UPDATE_INTERVAL") || "#{1 * 24 * 60 * 60}"),
  block_ranges: System.get_env("BLOCK_RANGES"),
  first_block: System.get_env("FIRST_BLOCK") || "",
  last_block: System.get_env("LAST_BLOCK") || "",
  trace_first_block: System.get_env("TRACE_FIRST_BLOCK") || "",
  trace_last_block: System.get_env("TRACE_LAST_BLOCK") || "",
  fetch_rewards_way: System.get_env("FETCH_REWARDS_WAY", "trace_block")

config :indexer, Indexer.Fetcher.TransactionAction.Supervisor,
  enabled: System.get_env("INDEXER_TX_ACTIONS_ENABLE", "false") == "true"

config :indexer, Indexer.Fetcher.TransactionAction,
  reindex_first_block: System.get_env("INDEXER_TX_ACTIONS_REINDEX_FIRST_BLOCK"),
  reindex_last_block: System.get_env("INDEXER_TX_ACTIONS_REINDEX_LAST_BLOCK"),
  reindex_protocols: System.get_env("INDEXER_TX_ACTIONS_REINDEX_PROTOCOLS", "")

config :indexer, Indexer.Transform.TransactionActions,
  max_token_cache_size: System.get_env("INDEXER_TX_ACTIONS_MAX_TOKEN_CACHE_SIZE")

{receipts_batch_size, _} = Integer.parse(System.get_env("INDEXER_RECEIPTS_BATCH_SIZE", "250"))
{receipts_concurrency, _} = Integer.parse(System.get_env("INDEXER_RECEIPTS_CONCURRENCY", "10"))

config :indexer,
  receipts_batch_size: receipts_batch_size,
  receipts_concurrency: receipts_concurrency

config :indexer, Indexer.Fetcher.PendingTransaction.Supervisor,
  disabled?:
    System.get_env("ETHEREUM_JSONRPC_VARIANT") == "besu" ||
      System.get_env("INDEXER_DISABLE_PENDING_TRANSACTIONS_FETCHER", "false") == "true"

token_balance_on_demand_fetcher_threshold_minutes = System.get_env("TOKEN_BALANCE_ON_DEMAND_FETCHER_THRESHOLD_MINUTES")

token_balance_on_demand_fetcher_threshold =
  case token_balance_on_demand_fetcher_threshold_minutes &&
         Integer.parse(token_balance_on_demand_fetcher_threshold_minutes) do
    {integer, ""} -> integer
    _ -> 60
  end

config :indexer, Indexer.Fetcher.TokenBalanceOnDemand,
  threshold: token_balance_on_demand_fetcher_threshold,
  fallback_treshold_in_blocks: 500

coin_balance_on_demand_fetcher_threshold_minutes = System.get_env("COIN_BALANCE_ON_DEMAND_FETCHER_THRESHOLD_MINUTES")

coin_balance_on_demand_fetcher_threshold =
  case coin_balance_on_demand_fetcher_threshold_minutes &&
         Integer.parse(coin_balance_on_demand_fetcher_threshold_minutes) do
    {integer, ""} -> integer
    _ -> 60
  end

config :indexer, Indexer.Fetcher.CoinBalanceOnDemand,
  threshold: coin_balance_on_demand_fetcher_threshold,
  fallback_treshold_in_blocks: 500

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

config :indexer, Indexer.Block.Realtime.Supervisor, enabled: System.get_env("DISABLE_REALTIME_INDEXER") != "true"

config :indexer, Indexer.Fetcher.TokenInstance.Supervisor,
  disabled?: System.get_env("DISABLE_TOKEN_INSTANCE_FETCHER", "false") == "true"

blocks_catchup_fetcher_batch_size_default_str = "10"
blocks_catchup_fetcher_concurrency_default_str = "10"

{blocks_catchup_fetcher_batch_size, _} =
  Integer.parse(System.get_env("INDEXER_CATCHUP_BLOCKS_BATCH_SIZE", blocks_catchup_fetcher_batch_size_default_str))

{blocks_catchup_fetcher_concurrency, _} =
  Integer.parse(System.get_env("INDEXER_CATCHUP_BLOCKS_CONCURRENCY", blocks_catchup_fetcher_concurrency_default_str))

config :indexer, Indexer.Block.Catchup.Fetcher,
  batch_size: blocks_catchup_fetcher_batch_size,
  concurrency: blocks_catchup_fetcher_concurrency

blocks_catchup_fetcher_missing_ranges_batch_size_default_str = "100000"

{blocks_catchup_fetcher_missing_ranges_batch_size, _} =
  Integer.parse(
    System.get_env(
      "INDEXER_CATCHUP_MISSING_RANGES_BATCH_SIZE",
      blocks_catchup_fetcher_missing_ranges_batch_size_default_str
    )
  )

config :indexer, Indexer.Block.Catchup.MissingRangesCollector,
  missing_ranges_batch_size: blocks_catchup_fetcher_missing_ranges_batch_size

{block_reward_fetcher_batch_size, _} = Integer.parse(System.get_env("INDEXER_BLOCK_REWARD_BATCH_SIZE", "10"))

{block_reward_fetcher_concurrency, _} = Integer.parse(System.get_env("INDEXER_BLOCK_REWARD_CONCURRENCY", "4"))

config :indexer, Indexer.Fetcher.BlockReward,
  batch_size: block_reward_fetcher_batch_size,
  concurrency: block_reward_fetcher_concurrency

{token_instance_fetcher_batch_size, _} = Integer.parse(System.get_env("INDEXER_TOKEN_INSTANCE_BATCH_SIZE", "1"))

{token_instance_fetcher_concurrency, _} = Integer.parse(System.get_env("INDEXER_TOKEN_INSTANCE_CONCURRENCY", "10"))

config :indexer, Indexer.Fetcher.TokenInstance,
  batch_size: token_instance_fetcher_batch_size,
  concurrency: token_instance_fetcher_concurrency

{internal_transaction_fetcher_batch_size, _} =
  Integer.parse(System.get_env("INDEXER_INTERNAL_TRANSACTIONS_BATCH_SIZE", "10"))

{internal_transaction_fetcher_concurrency, _} =
  Integer.parse(System.get_env("INDEXER_INTERNAL_TRANSACTIONS_CONCURRENCY", "4"))

config :indexer, Indexer.Fetcher.InternalTransaction,
  batch_size: internal_transaction_fetcher_batch_size,
  concurrency: internal_transaction_fetcher_concurrency

{coin_balance_fetcher_batch_size, _} = Integer.parse(System.get_env("INDEXER_COIN_BALANCES_BATCH_SIZE", "500"))

{coin_balance_fetcher_concurrency, _} = Integer.parse(System.get_env("INDEXER_COIN_BALANCES_CONCURRENCY", "4"))

config :indexer, Indexer.Fetcher.CoinBalance,
  batch_size: coin_balance_fetcher_batch_size,
  concurrency: coin_balance_fetcher_concurrency

Code.require_file("#{config_env()}.exs", "config/runtime")

for config <- "../apps/*/config/runtime/#{config_env()}.exs" |> Path.expand(__DIR__) |> Path.wildcard() do
  Code.require_file("#{config_env()}.exs", Path.dirname(config))
end
