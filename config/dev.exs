import Config

# DO NOT make it `:debug` or all Ecto logs will be shown for indexer
config :logger, :console, level: :info

config :logger, :ecto,
  level: :debug,
  path: Path.absname("logs/dev/ecto.log")

config :logger, :error, path: Path.absname("logs/dev/error.log")

config :logger, :account,
  level: :debug,
  path: Path.absname("logs/dev/account.log"),
  metadata_filter: [fetcher: :account]
