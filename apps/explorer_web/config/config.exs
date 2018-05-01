# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.
use Mix.Config

# General application configuration
config :explorer_web,
  namespace: ExplorerWeb,
  ecto_repos: [Explorer.Repo]

# Configures the endpoint
config :explorer_web, ExplorerWeb.Endpoint,
  url: [host: "localhost"],
  render_errors: [view: ExplorerWeb.ErrorView, accepts: ~w(html json)],
  pubsub: [name: ExplorerWeb.PubSub, adapter: Phoenix.PubSub.PG2]

# Configures gettext
config :explorer_web, ExplorerWeb.Gettext, locales: ~w(en), default_locale: "en"

config :explorer_web, ExplorerWeb.SocialMedia,
  facebook: "https://www.facebook.com/PoaNetwork",
  instagram: "https://www.instagram.com/PoaNetwork",
  twitter: "https://www.twitter.com/PoaNetwork"

config :ex_cldr,
  default_locale: "en",
  locales: ["en"],
  gettext: ExplorerWeb.Gettext

config :exq_ui, server: false

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
