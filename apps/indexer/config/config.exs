# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

config :indexer,
  block_rate: 5_000,
  debug_logs: !!System.get_env("DEBUG_INDEXER")

config :indexer, ecto_repos: [Explorer.Repo]
