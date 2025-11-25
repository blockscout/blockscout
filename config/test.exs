import Config

# Print only warnings and errors during test
config :logger, level: :warn

config :logger, :error, path: Path.absname("logs/test/error.log")
