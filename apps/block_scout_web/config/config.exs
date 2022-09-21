# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.
import Config

alias BlockScoutWeb.LoggerBackend

# General application configuration
config :block_scout_web,
  namespace: BlockScoutWeb,
  ecto_repos: [Explorer.Repo],
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
  staking_enabled: not is_nil(System.get_env("POS_STAKING_CONTRACT")),
  staking_enabled_in_menu: System.get_env("ENABLE_POS_STAKING_IN_MENU", "false") == "true",
  show_staking_warning: System.get_env("SHOW_STAKING_WARNING", "false") == "true",
  show_maintenance_alert: System.get_env("SHOW_MAINTENANCE_ALERT", "false") == "true",
  # how often (in blocks) the list of pools should autorefresh in UI (zero turns off autorefreshing)
  staking_pool_list_refresh_interval: 5

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
  eth_omni_bridge_mediator: System.get_env("ETH_OMNI_BRIDGE_MEDIATOR"),
  bsc_omni_bridge_mediator: System.get_env("BSC_OMNI_BRIDGE_MEDIATOR"),
  amb_bridge_mediators: System.get_env("AMB_BRIDGE_MEDIATORS"),
  foreign_json_rpc: System.get_env("FOREIGN_JSON_RPC", ""),
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
  re_captcha_project_id: System.get_env("RE_CAPTCHA_PROJECT_ID", nil),
  chain_id: System.get_env("CHAIN_ID"),
  json_rpc: System.get_env("JSON_RPC")

global_api_rate_limit_value =
  "API_RATE_LIMIT"
  |> System.get_env("50")
  |> Integer.parse()
  |> case do
    {integer, ""} -> integer
    _ -> 50
  end

api_rate_limit_by_key_value =
  "API_RATE_LIMIT_BY_KEY"
  |> System.get_env("50")
  |> Integer.parse()
  |> case do
    {integer, ""} -> integer
    _ -> 50
  end

api_rate_limit_by_ip_value =
  "API_RATE_LIMIT_BY_IP"
  |> System.get_env("50")
  |> Integer.parse()
  |> case do
    {integer, ""} -> integer
    _ -> 50
  end

config :block_scout_web, :api_rate_limit,
  global_limit: global_api_rate_limit_value,
  limit_by_key: api_rate_limit_by_key_value,
  limit_by_ip: api_rate_limit_by_ip_value,
  static_api_key: System.get_env("API_RATE_LIMIT_STATIC_API_KEY", nil),
  whitelisted_ips: System.get_env("API_RATE_LIMIT_WHITELISTED_IPS", nil)

config :block_scout_web, BlockScoutWeb.Counters.BlocksIndexedCounter, enabled: true

# Configures the endpoint
config :block_scout_web, BlockScoutWeb.Endpoint,
  url: [
    scheme: System.get_env("BLOCKSCOUT_PROTOCOL") || "http",
    host: System.get_env("BLOCKSCOUT_HOST") || "localhost",
    path: System.get_env("NETWORK_PATH") || "/",
    api_path: System.get_env("API_PATH") || "/"
  ],
  render_errors: [view: BlockScoutWeb.ErrorView, accepts: ~w(html json)],
  pubsub_server: BlockScoutWeb.PubSub

config :block_scout_web, BlockScoutWeb.Tracer,
  service: :block_scout_web,
  adapter: SpandexDatadog.Adapter,
  trace_key: :blockscout

# Configures gettext
config :block_scout_web, BlockScoutWeb.Gettext, locales: ~w(en), default_locale: "en"

config :block_scout_web, BlockScoutWeb.SocialMedia,
  twitter: "PoaNetwork",
  telegram: "poa_network",
  facebook: "PoaNetwork",
  instagram: "PoaNetwork"

# Configures History
price_chart_config =
  if System.get_env("SHOW_PRICE_CHART", "true") != "false" do
    %{market: [:price, :market_cap]}
  else
    %{}
  end

tx_chart_config =
  if System.get_env("SHOW_TXS_CHART", "false") == "true" do
    %{transactions: [:transactions_per_day]}
  else
    %{}
  end

config :block_scout_web,
  chart_config: Map.merge(price_chart_config, tx_chart_config)

config :block_scout_web, BlockScoutWeb.Chain.TransactionHistoryChartController,
  # days
  history_size: 30

config :block_scout_web, BlockScoutWeb.Chain.Address.CoinBalance,
  # days
  coin_balance_history_days: System.get_env("COIN_BALANCE_HISTORY_DAYS", "10")

config :ex_cldr,
  default_locale: "en",
  default_backend: BlockScoutWeb.Cldr

config :logger_json, :block_scout_web,
  metadata:
    ~w(application fetcher request_id first_block_number last_block_number missing_block_range_count missing_block_count
       block_number step count error_count shrunk import_id transaction_id)a,
  metadata_filter: [application: :block_scout_web]

config :logger, :block_scout_web, backends: [LoggerJSON]

# config :logger, :block_scout_web,
#  # keep synced with `config/config.exs`
#  format: "$dateT$time $metadata[$level] $message\n",
#  metadata:
#    ~w(application fetcher request_id first_block_number last_block_number missing_block_range_count missing_block_count
#       block_number step count error_count shrunk import_id transaction_id)a,
#  metadata_filter: [application: :block_scout_web]

config :prometheus, BlockScoutWeb.Prometheus.Instrumenter,
  # override default for Phoenix 1.4 compatibility
  # * `:transport_name` to `:transport`
  # * remove `:vsn`
  channel_join_labels: [:channel, :topic, :transport],
  # override default for Phoenix 1.4 compatibility
  # * `:transport_name` to `:transport`
  # * remove `:vsn`
  channel_receive_labels: [:channel, :topic, :transport, :event]

config :spandex_phoenix, tracer: BlockScoutWeb.Tracer

config :wobserver,
  # return only the local node
  discovery: :none,
  mode: :plug

config :block_scout_web, BlockScoutWeb.ApiRouter,
  max_complexity: String.to_integer(System.get_env("GRAPHQL_COMPLEXITY") || "12000"),
  writing_enabled: System.get_env("DISABLE_WRITE_API") != "true",
  reading_enabled: System.get_env("DISABLE_READ_API") != "true",
  wobserver_enabled: System.get_env("WOBSERVER_ENABLED") == "true"

config :block_scout_web, BlockScoutWeb.WebRouter, enabled: System.get_env("DISABLE_WEBAPP") != "true"

config :hammer,
  backend: {Hammer.Backend.ETS, [expiry_ms: 60_000 * 60 * 4, cleanup_interval_ms: 60_000 * 10]}

config :prometheus, BlockScoutWeb.Prometheus.Exporter, path: "/metrics/web"

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
