use Mix.Config

# DO NOT make it `:debug` or all Ecto logs will be shown for indexer
config :logger, :console, level: :info

config :logger, :ecto,
  level: :debug,
  path: Path.absname("logs/dev/ecto.log")

config :logger, :error, path: Path.absname("logs/dev/error.log")

# System.get_env("ETHEREUM_JSONRPC_HTTP_URL")
config :ethereumex, url: "https://sokol.poa.network"
