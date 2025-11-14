import Config

config :logger, level: :info

config :logger, :ecto_sql, path: Path.absname("logs/dev/ecto.log")

config :logger, :error, path: Path.absname("logs/dev/error.log")

config :logger, :account,
  path: Path.absname("logs/dev/account.log"),
  metadata_filter: [fetcher: :account]
