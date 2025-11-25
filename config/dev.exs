import Config

config :logger, level: :info

config :logger, :error, path: Path.absname("logs/dev/error.log"), level: :error

config :logger, :account,
  path: Path.absname("logs/dev/account.log"),
  metadata_filter: [fetcher: :account]
