# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.
use Mix.Config

# General application configuration
config :block_scout_web,
  namespace: BlockScoutWeb,
  ecto_repos: [Explorer.Repo],
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
  has_emission_funds: false,
  staking_enabled: not is_nil(System.get_env("POS_STAKING_CONTRACT")),
  # how often (in blocks) the list of pools should autorefresh in UI (zero turns off autorefreshing)
  staking_pool_list_refresh_interval: 5

config :block_scout_web,
  link_to_other_explorers: System.get_env("LINK_TO_OTHER_EXPLORERS") == "true",
  other_explorers: %{
    "Etherscan" => "https://etherscan.io/",
    "EtherChain" => "https://www.etherchain.org/",
    "Bloxy" => "https://bloxy.info/"
  },
  other_networks: System.get_env("SUPPORTED_CHAINS"),
  webapp_url: System.get_env("WEBAPP_URL"),
  api_url: System.get_env("API_URL")

config :block_scout_web, BlockScoutWeb.Counters.BlocksIndexedCounter, enabled: true

# Configures the endpoint
config :block_scout_web, BlockScoutWeb.Endpoint,
  instrumenters: [BlockScoutWeb.Prometheus.Instrumenter, SpandexPhoenix.Instrumenter],
  url: [
    scheme: System.get_env("BLOCKSCOUT_PROTOCOL") || "http",
    host: System.get_env("BLOCKSCOUT_HOST") || "localhost",
    path: System.get_env("NETWORK_PATH") || "/",
    api_path: System.get_env("API_PATH") || "/"
  ],
  render_errors: [view: BlockScoutWeb.ErrorView, accepts: ~w(html json)],
  pubsub: [name: BlockScoutWeb.PubSub]

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

config :logger, :block_scout_web,
  # keep synced with `config/config.exs`
  format: "$dateT$time $metadata[$level] $message\n",
  metadata:
    ~w(application fetcher request_id first_block_number last_block_number missing_block_range_count missing_block_count
       block_number step count error_count shrunk import_id transaction_id)a,
  metadata_filter: [application: :block_scout_web]

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
  writing_enabled: System.get_env("DISABLE_WRITE_API") != "true",
  reading_enabled: System.get_env("DISABLE_READ_API") != "true"

config :block_scout_web, BlockScoutWeb.WebRouter, enabled: System.get_env("DISABLE_WEBAPP") != "true"

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
