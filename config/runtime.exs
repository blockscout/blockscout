import Config

import Bitwise

indexer_memory_limit =
  "INDEXER_MEMORY_LIMIT"
  |> System.get_env("1")
  |> Integer.parse()
  |> case do
    {integer, ""} -> integer
    _ -> 1
  end

config :indexer,
  memory_limit: indexer_memory_limit <<< 32

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

config :block_scout_web, :footer,
  chat_link: System.get_env("FOOTER_CHAT_LINK", "http://discord.gg/celo"),
  forum_link: System.get_env("FOOTER_FORUM_LINK", "https://forum.celo.org/"),
  github_link: System.get_env("FOOTER_GITHUB_LINK", "https://github.com/celo-org/blockscout")

######################
### BlockScout Web ###
######################

config :block_scout_web,
  version: System.get_env("BLOCKSCOUT_VERSION"),
  segment_key: System.get_env("SEGMENT_KEY"),
  release_link: System.get_env("RELEASE_LINK"),
  decompiled_smart_contract_token: System.get_env("DECOMPILED_SMART_CONTRACT_TOKEN"),
  show_percentage: if(System.get_env("SHOW_ADDRESS_MARKETCAP_PERCENTAGE", "true") == "false", do: false, else: true),
  checksum_address_hashes: if(System.get_env("CHECKSUM_ADDRESS_HASHES", "true") == "false", do: false, else: true)

config :block_scout_web, BlockScoutWeb.Chain,
  network: System.get_env("NETWORK"),
  subnetwork: System.get_env("SUBNETWORK"),
  network_icon: System.get_env("NETWORK_ICON"),
  logo: System.get_env("LOGO", "/images/celo_logo.svg"),
  logo_footer: System.get_env("LOGO_FOOTER", "/images/celo_logo.svg"),
  logo_text: System.get_env("LOGO_TEXT"),
  has_emission_funds: false,
  show_maintenance_alert: System.get_env("SHOW_MAINTENANCE_ALERT", "false") == "true",
  enable_testnet_label: System.get_env("SHOW_TESTNET_LABEL", "false") == "true",
  testnet_label_text: System.get_env("TESTNET_LABEL_TEXT", "Testnet")

config :block_scout_web,
  link_to_other_explorers: System.get_env("LINK_TO_OTHER_EXPLORERS") == "true",
  other_explorers: System.get_env("OTHER_EXPLORERS"),
  swap: System.get_env("SWAP_MENU_LIST"),
  defi: System.get_env("DEFI_MENU_LIST"),
  wallet_list: System.get_env("WALLET_MENU_LIST"),
  nft_list: System.get_env("NFT_MENU_LIST"),
  connect_list: System.get_env("CONNECT_MENU_LIST"),
  spend_list: System.get_env("SPEND_MENU_LIST"),
  finance_tools_list: System.get_env("FINANCE_TOOLS_MENU_LIST"),
  resources: System.get_env("RESOURCES_MENU_LIST"),
  learning: System.get_env("LEARNING_MENU_LIST"),
  other_networks: System.get_env("SUPPORTED_CHAINS"),
  webapp_url: System.get_env("WEBAPP_URL"),
  api_url: System.get_env("API_URL"),
  apps_menu: if(System.get_env("APPS_MENU", "false") == "true", do: true, else: false),
  stats_enabled: System.get_env("DISABLE_STATS") != "true",
  stats_report_url: System.get_env("STATS_REPORT_URL", ""),
  makerdojo_url: System.get_env("MAKERDOJO_URL", ""),
  gas_price: System.get_env("GAS_PRICE", nil),
  restricted_list: System.get_env("RESTRICTED_LIST", nil),
  restricted_list_key: System.get_env("RESTRICTED_LIST_KEY", nil),
  dark_forest_addresses: System.get_env("CUSTOM_CONTRACT_ADDRESSES_DARK_FOREST"),
  dark_forest_addresses_v_0_5: System.get_env("CUSTOM_CONTRACT_ADDRESSES_DARK_FOREST_V_0_5"),
  circles_addresses: System.get_env("CUSTOM_CONTRACT_ADDRESSES_CIRCLES"),
  test_tokens_addresses: System.get_env("CUSTOM_CONTRACT_ADDRESSES_TEST_TOKEN"),
  max_size_to_show_array_as_is: Integer.parse(System.get_env("MAX_SIZE_UNLESS_HIDE_ARRAY", "50")),
  max_length_to_show_string_without_trimming: System.get_env("MAX_STRING_LENGTH_WITHOUT_TRIMMING", "2040"),
  re_captcha_site_key: System.get_env("RE_CAPTCHA_SITE_KEY", nil),
  re_captcha_api_key: System.get_env("RE_CAPTCHA_API_KEY", nil),
  re_captcha_secret_key: System.get_env("RE_CAPTCHA_SECRET_KEY", nil),
  re_captcha_project_id: System.get_env("RE_CAPTCHA_PROJECT_ID", nil),
  chain_id: System.get_env("CHAIN_ID"),
  json_rpc: System.get_env("JSON_RPC")

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

########################
### Ethereum JSONRPC ###
########################

config :ethereum_jsonrpc,
  rpc_transport: if(System.get_env("ETHEREUM_JSONRPC_TRANSPORT", "http") == "http", do: :http, else: :ipc),
  ipc_path: System.get_env("IPC_PATH"),
  disable_archive_balances?: System.get_env("ETHEREUM_JSONRPC_DISABLE_ARCHIVE_BALANCES", "false") == "true"

debug_trace_transaction_timeout = System.get_env("ETHEREUM_JSONRPC_DEBUG_TRACE_TRANSACTION_TIMEOUT", "900s")
config :ethereum_jsonrpc, :internal_transaction_timeout, debug_trace_transaction_timeout

################
### Explorer ###
################

disable_indexer = System.get_env("DISABLE_INDEXER")
disable_webapp = System.get_env("DISABLE_WEBAPP")

healthy_blocks_period =
  case Integer.parse(System.get_env("HEALTHY_BLOCKS_PERIOD", "")) do
    {secs, ""} -> :timer.seconds(secs)
    _ -> :timer.minutes(5)
  end

config :explorer,
  coin: System.get_env("COIN") || "CELO",
  coin_name: System.get_env("COIN_NAME") || System.get_env("COIN") || "CELO",
  allowed_evm_versions:
    System.get_env("ALLOWED_EVM_VERSIONS") ||
      "homestead,tangerineWhistle,spuriousDragon,byzantium,constantinople,petersburg,istanbul,berlin,london,default",
  include_uncles_in_average_block_time:
    if(System.get_env("UNCLES_IN_AVERAGE_BLOCK_TIME") == "true", do: true, else: false),
  healthy_blocks_period: healthy_blocks_period,
  realtime_events_sender:
    if(disable_webapp != "true",
      do: Explorer.Chain.Events.SimpleSender,
      else: Explorer.Chain.Events.PubSubSender
    )

config :explorer, Explorer.Chain.Events.Listener,
  enabled:
    if(disable_webapp == "true" && disable_indexer == "true",
      do: false,
      else: true
    ),
  event_source: Explorer.Chain.Events.PubSubSource

config :explorer, Explorer.ChainSpec.GenesisData,
  chain_spec_path:
    System.get_env(
      "CHAIN_SPEC_PATH",
      "https://www.googleapis.com/storage/v1/b/genesis_blocks/o/#{String.downcase(System.get_env("SUBNETWORK", "Baklava"))}?alt=media"
    ),
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
    {integer, ""} -> :timer.seconds(integer)
    _ -> :timer.minutes(60)
  end

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

case System.get_env("MARKET_CAP_ENABLED", "false") do
  "false" ->
    config :explorer, market_cap_enabled: false

  _ ->
    config :explorer, market_cap_enabled: true
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

###############
### Indexer ###
###############

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
  ecto_repos: [Explorer.Repo.Local],
  metadata_updater_seconds_interval:
    String.to_integer(System.get_env("TOKEN_METADATA_UPDATE_INTERVAL") || "#{2 * 24 * 60 * 60}"),
  health_check_port: port || 4001,
  block_ranges: System.get_env("BLOCK_RANGES") || "",
  first_block: System.get_env("FIRST_BLOCK") || "",
  last_block: System.get_env("LAST_BLOCK") || "",
  metrics_enabled: System.get_env("METRICS_ENABLED") || false,
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

if File.exists?("#{Path.absname(__DIR__)}/runtime/#{config_env()}.exs") do
  Code.require_file("#{config_env()}.exs", "#{Path.absname(__DIR__)}/runtime")
end

for config <- "../apps/*/config/runtime/#{config_env()}.exs" |> Path.expand(__DIR__) |> Path.wildcard() do
  if File.exists?(config) do
    Code.require_file("#{config_env()}.exs", Path.dirname(config))
  end
end
