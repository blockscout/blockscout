import Config

# Print only warnings and errors during test

config :logger, :console, level: :warn

config :logger_json, :backend, level: :none

config :logger, :ecto,
  level: :warn,
  path: Path.absname("logs/test/ecto.log")

config :logger, :error, path: Path.absname("logs/test/error.log")
