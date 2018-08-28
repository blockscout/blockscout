use Mix.Config

# DO NOT make it `:debug` or all Ecto logs will be shown for indexer
config :logger, :console, level: :info

config :logger, :ecto,
  level: :debug,
  path: "logs/dev/ecto.log"

config :logger, :error, path: "logs/dev/error.log"
