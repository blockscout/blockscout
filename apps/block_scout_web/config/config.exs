# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.
use Mix.Config

# General application configuration
config :block_scout_web,
  namespace: BlockScoutWeb,
  ecto_repos: [Explorer.Repo]

config :block_scout_web, BlockScoutWeb.Chain,
  network: System.get_env("NETWORK"),
  subnetwork: System.get_env("SUBNETWORK"),
  network_icon: System.get_env("NETWORK_ICON"),
  logo: System.get_env("LOGO")

# Configures the endpoint
config :block_scout_web, BlockScoutWeb.Endpoint,
  instrumenters: [BlockScoutWeb.Prometheus.Instrumenter],
  url: [
    host: "localhost",
    path: System.get_env("NETWORK_PATH") || "/"
  ],
  render_errors: [view: BlockScoutWeb.ErrorView, accepts: ~w(html json)],
  pubsub: [name: BlockScoutWeb.PubSub, adapter: Phoenix.PubSub.PG2]

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
  format: "$time $metadata[$level] $message\n",
  metadata: [:application, :request_id],
  metadata_filter: [application: :block_scout_web]

config :wobserver,
  # return only the local node
  discovery: :none,
  mode: :plug

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
