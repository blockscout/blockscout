import Config

import Bitwise

indexer_memory_limit_default = 1

indexer_memory_limit =
  "INDEXER_MEMORY_LIMIT"
  |> System.get_env(to_string(indexer_memory_limit_default))
  |> Integer.parse()
  |> case do
    {integer, ""} -> integer
    _ -> indexer_memory_limit_default
  end

config :indexer,
  memory_limit: indexer_memory_limit <<< 30

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

config :block_scout_web, :footer,
  chat_link: System.get_env("FOOTER_CHAT_LINK", "https://discord.gg/blockscout"),
  forum_link: System.get_env("FOOTER_FORUM_LINK", "https://forum.poa.network/c/blockscout"),
  github_link: System.get_env("FOOTER_GITHUB_LINK", "https://github.com/blockscout/blockscout"),
  enable_forum_link: System.get_env("FOOTER_ENABLE_FORUM_LINK", "false") == "true"

######################
### BlockScout Web ###
######################

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
  has_emission_funds: true,
  show_maintenance_alert: System.get_env("SHOW_MAINTENANCE_ALERT", "false") == "true",
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
  other_networks: System.get_env("SUPPORTED_CHAINS"),
  webapp_url: System.get_env("WEBAPP_URL"),
  api_url: System.get_env("API_URL"),
  apps_menu: if(System.get_env("APPS_MENU", "false") == "true", do: true, else: false),
  external_apps: System.get_env("EXTERNAL_APPS"),
  gas_price: System.get_env("GAS_PRICE", nil),
  restricted_list: System.get_env("RESTRICTED_LIST", nil),
  restricted_list_key: System.get_env("RESTRICTED_LIST_KEY", nil),
  dark_forest_addresses: System.get_env("CUSTOM_CONTRACT_ADDRESSES_DARK_FOREST"),
  dark_forest_addresses_v_0_5: System.get_env("CUSTOM_CONTRACT_ADDRESSES_DARK_FOREST_V_0_5"),
  circles_addresses: System.get_env("CUSTOM_CONTRACT_ADDRESSES_CIRCLES"),
  test_tokens_addresses: System.get_env("CUSTOM_CONTRACT_ADDRESSES_TEST_TOKEN"),
  max_size_to_show_array_as_is: Integer.parse(System.get_env("MAX_SIZE_UNLESS_HIDE_ARRAY", "50")),
  max_length_to_show_string_without_trimming: System.get_env("MAX_STRING_LENGTH_WITHOUT_TRIMMING", "2040"),
  re_captcha_secret_key: System.get_env("RE_CAPTCHA_SECRET_KEY", nil),
  re_captcha_client_key: System.get_env("RE_CAPTCHA_CLIENT_KEY", nil),
  new_tags: System.get_env("NEW_TAGS"),
  chain_id: System.get_env("CHAIN_ID"),
  json_rpc: System.get_env("JSON_RPC"),
  verification_max_libraries: verification_max_libraries

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

config :block_scout_web,
  chart_config: Map.merge(price_chart_config, tx_chart_config)

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
config :ethereum_jsonrpc, EthereumJSONRPC.Geth, debug_trace_transaction_timeout: debug_trace_transaction_timeout

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
    )

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

config :explorer, Explorer.ExchangeRates,
  store: :ets,
  enabled: System.get_env("DISABLE_EXCHANGE_RATES") != "true",
  coingecko_coin_id: System.get_env("EXCHANGE_RATES_COINGECKO_COIN_ID"),
  coingecko_api_key: System.get_env("EXCHANGE_RATES_COINGECKO_API_KEY"),
  coinmarketcap_api_key: System.get_env("EXCHANGE_RATES_COINMARKETCAP_API_KEY"),
  fetch_btc_value: System.get_env("EXCHANGE_RATES_FETCH_BTC_VALUE") == "true"

exchange_rates_source =
  cond do
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

case System.get_env("SUPPLY_MODULE") do
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

config :explorer, Explorer.SmartContract.RustVerifierInterface,
  service_url: System.get_env("RUST_VERIFICATION_SERVICE_URL"),
  enabled: System.get_env("ENABLE_RUST_VERIFICATION_SERVICE") == "true"

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
    String.to_integer(System.get_env("TOKEN_METADATA_UPDATE_INTERVAL") || "#{2 * 24 * 60 * 60}"),
  block_ranges: System.get_env("BLOCK_RANGES") || "",
  first_block: System.get_env("FIRST_BLOCK") || "",
  last_block: System.get_env("LAST_BLOCK") || "",
  trace_first_block: System.get_env("TRACE_FIRST_BLOCK") || "",
  trace_last_block: System.get_env("TRACE_LAST_BLOCK") || "",
  fetch_rewards_way: System.get_env("FETCH_REWARDS_WAY", "trace_block")

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

config :indexer, Indexer.Fetcher.TokenBalanceOnDemand, threshold: token_balance_on_demand_fetcher_threshold

coin_balance_on_demand_fetcher_threshold_minutes = System.get_env("COIN_BALANCE_ON_DEMAND_FETCHER_THRESHOLD_MINUTES")

coin_balance_on_demand_fetcher_threshold =
  case coin_balance_on_demand_fetcher_threshold_minutes &&
         Integer.parse(coin_balance_on_demand_fetcher_threshold_minutes) do
    {integer, ""} -> integer
    _ -> 60
  end

config :indexer, Indexer.Fetcher.CoinBalanceOnDemand, threshold: coin_balance_on_demand_fetcher_threshold

config :indexer, Indexer.Fetcher.BlockReward.Supervisor,
  disabled?: System.get_env("INDEXER_DISABLE_BLOCK_REWARD_FETCHER", "false") == "true"

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

Code.require_file("#{config_env()}.exs", "config/runtime")

for config <- "../apps/*/config/runtime/#{config_env()}.exs" |> Path.expand(__DIR__) |> Path.wildcard() do
  Code.require_file("#{config_env()}.exs", Path.dirname(config))
end
