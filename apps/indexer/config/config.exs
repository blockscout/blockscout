# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

config :indexer,
  debug_logs: !!System.get_env("DEBUG_INDEXER"),
  ecto_repos: [Explorer.Repo]

variant = System.get_env("ETHEREUM_JSONRPC_VARIANT") || "parity"

# Import variant specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{variant}.exs"
