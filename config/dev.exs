use Mix.Config

# DO NOT make it `:debug` or all Ecto logs will be shown for indexer
# DO NOT make it `:info` or all missing block logs will be shown for indexer
config :logger, :console, level: :warn

config :logger, :ecto,
  level: :debug,
  path: Path.absname("logs/dev/ecto.log")

config :logger, :error, path: Path.absname("logs/dev/error.log")
