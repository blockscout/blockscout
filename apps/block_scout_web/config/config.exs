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
  decompiled_smart_contract_token: System.get_env("DECOMPILED_SMART_CONTRACT_TOKEN")

config :block_scout_web, BlockScoutWeb.Chain,
  network: System.get_env("NETWORK"),
  subnetwork: System.get_env("SUBNETWORK"),
  network_icon: System.get_env("NETWORK_ICON"),
  logo: System.get_env("LOGO") || "/images/poa_logo.svg",
  has_emission_funds: true

config :block_scout_web,
  link_to_other_explorers: System.get_env("LINK_TO_OTHER_EXPLORERS") == "true",
  other_explorers: %{
    "Etherscan" => "https://etherscan.io/",
    "EtherChain" => "https://www.etherchain.org/",
    "Bloxy" => "https://bloxy.info/"
  },
  other_networks: [
    %{
      title: "POA Core",
      url: "https://blockscout.com/poa/core"
    },
    %{
      title: "POA Sokol",
      url: "https://blockscout.com/poa/sokol",
      test_net?: true
    },
    %{
      title: "xDai Chain",
      url: "https://blockscout.com/poa/dai"
    },
    %{
      title: "Ethereum Mainnet",
      url: "https://blockscout.com/eth/mainnet"
    },
    %{
      title: "Kovan Testnet",
      url: "https://blockscout.com/eth/kovan",
      test_net?: true
    },
    %{
      title: "Ropsten Testnet",
      url: "https://blockscout.com/eth/ropsten",
      test_net?: true
    },
    %{
      title: "Goerli Testnet",
      url: "https://blockscout.com/eth/goerli",
      test_net?: true
    },
    %{
      title: "Rinkeby Testnet",
      url: "https://blockscout.com/eth/rinkeby",
      test_net?: true
    },
    %{
      title: "Ethereum Classic",
      url: "https://blockscout.com/etc/mainnet"
    }
  ]

config :block_scout_web, BlockScoutWeb.Counters.BlocksIndexedCounter, enabled: true

# Configures the endpoint
config :block_scout_web, BlockScoutWeb.Endpoint,
  instrumenters: [BlockScoutWeb.Prometheus.Instrumenter, SpandexPhoenix.Instrumenter],
  url: [
    host: "localhost",
    path: System.get_env("NETWORK_PATH") || "/"
  ],
  render_errors: [view: BlockScoutWeb.ErrorView, accepts: ~w(html json)],
  pubsub: [name: BlockScoutWeb.PubSub, adapter: Phoenix.PubSub.PG2]

config :block_scout_web, BlockScoutWeb.Tracer,
  service: :block_scout_web,
  adapter: SpandexDatadog.Adapter,
  trace_key: :blockscout

# Configures gettext
config :block_scout_web, BlockScoutWeb.Gettext, locales: ~w(en), default_locale: "en"

config :block_scout_web, BlockScoutWeb.SocialMedia,
  twitter: "PoaNetwork",
  telegram: "oraclesnetwork",
  facebook: "PoaNetwork",
  instagram: "PoaNetwork"

config :ex_cldr,
  default_locale: "en",
  locales: ["en"],
  gettext: BlockScoutWeb.Gettext

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

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
