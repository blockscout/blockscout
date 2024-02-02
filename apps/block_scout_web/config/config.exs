# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.
import Config

# General application configuration
config :block_scout_web,
  namespace: BlockScoutWeb,
  ecto_repos: [Explorer.Repo, Explorer.Repo.Account],
  cookie_domain: System.get_env("SESSION_COOKIE_DOMAIN")

config :block_scout_web,
  admin_panel_enabled: System.get_env("ADMIN_PANEL_ENABLED", "") == "true"

config :block_scout_web, BlockScoutWeb.Counters.BlocksIndexedCounter, enabled: true

config :block_scout_web, BlockScoutWeb.Counters.InternalTransactionsIndexedCounter, enabled: true

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

config :block_scout_web, BlockScoutWeb.Chain.TransactionHistoryChartController,
  # days
  history_size: 30

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

config :logger, :api,
  # keep synced with `config/config.exs`
  format: "$dateT$time $metadata[$level] $message\n",
  metadata:
    ~w(application fetcher request_id first_block_number last_block_number missing_block_range_count missing_block_count
       block_number step count error_count shrunk import_id transaction_id)a,
  metadata_filter: [application: :api]

config :logger, :api_v2,
  # keep synced with `config/config.exs`
  format: "$dateT$time $metadata[$level] $message\n",
  metadata:
    ~w(application fetcher request_id first_block_number last_block_number missing_block_range_count missing_block_count
       block_number step count error_count shrunk import_id transaction_id)a,
  metadata_filter: [application: :api_v2]

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

config :block_scout_web, BlockScoutWeb.ApiRouter,
  writing_enabled: System.get_env("API_V1_WRITE_METHODS_DISABLED") != "true",
  reading_enabled: System.get_env("API_V1_READ_METHODS_DISABLED") != "true"

config :block_scout_web, BlockScoutWeb.WebRouter, enabled: System.get_env("DISABLE_WEBAPP") != "true"

config :block_scout_web, BlockScoutWeb.CSPHeader,
  mixpanel_url: System.get_env("MIXPANEL_URL", "https://api-js.mixpanel.com"),
  amplitude_url: System.get_env("AMPLITUDE_URL", "https://api2.amplitude.com/2/httpapi")

# Configures Ueberauth local settings
config :ueberauth, Ueberauth,
  providers: [
    auth0: {
      Ueberauth.Strategy.Auth0,
      [callback_path: "/auth/auth0/callback", callback_params: ["path"]]
    }
  ]

redis_url = System.get_env("API_RATE_LIMIT_HAMMER_REDIS_URL")

if is_nil(redis_url) or redis_url == "" do
  config :hammer, backend: {Hammer.Backend.ETS, [expiry_ms: 60_000 * 60 * 4, cleanup_interval_ms: 60_000 * 10]}
else
  config :hammer,
    backend:
      {Hammer.Backend.Redis,
       [
         delete_buckets_timeout: 60_000 * 10,
         expiry_ms: 60_000 * 60 * 4,
         redis_url: redis_url
       ]}
end

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
