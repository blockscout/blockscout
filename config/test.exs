import Config

config :logger, level: :warn

config :logger, :ecto_sql, path: Path.absname("logs/test/ecto.log")

config :logger, :error, path: Path.absname("logs/test/error.log")
