import Config
config :explorer, Oban, testing: :manual

# Print only warnings and errors during test
config :logger, level: :warn

config :logger, :error, path: Path.absname("logs/test/error.log")
