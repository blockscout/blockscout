use Mix.Config

# DO NOT make it `:debug` or all Ecto logs will be shown for indexer
config :logger, :console, level: :info

config :logger, :ecto,
  level: :debug,
  path: Path.absname("logs/dev/ecto.log")

config :logger, :error, path: Path.absname("logs/dev/error.log")


config :block_scout_web, BlockScoutWeb.Endpoint,
    http: [port: 4000],
    https: [
      port: 4001,
      cipher_suite: :strong,
      certfile: "priv/cert/selfsigned.pem",
      keyfile: "priv/cert/selfsigned_key.pem"
    ]
