# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

config :indexer,
  ecto_repos: [Explorer.Repo]

config :logger, :indexer,
  # keep synced with `config/config.exs`
  format: "$time $metadata[$level] $message\n",
  metadata: [:application, :request_id],
  metadata_filter: [application: :indexer]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
