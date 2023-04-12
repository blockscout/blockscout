import Config

# Do not print debug messages in production

config :logger, :console, level: :info

config :logger, :ecto,
  level: :info,
  path: Path.absname("logs/prod/ecto.log"),
  rotate: %{max_bytes: 52_428_800, keep: 19}

config :logger, :error,
  path: Path.absname("logs/prod/error.log"),
  rotate: %{max_bytes: 52_428_800, keep: 19}

# System.get_env("ETHEREUM_JSONRPC_HTTP_URL")
# config :ethereumex, url: System.get_env("FAUCET_JSONRPC_HTTP_URL")

config :logger, :account,
  level: :info,
  path: Path.absname("logs/prod/account.log"),
  rotate: %{max_bytes: 52_428_800, keep: 19},
  metadata_filter: [fetcher: :account]
