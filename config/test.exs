import Config

# Print only warnings and errors during test

config :logger, :console, level: :warn

config :logger, :ecto,
  level: :warn,
  path: Path.absname("logs/test/ecto.log")

config :logger, :error, path: Path.absname("logs/test/error.log")

config :explorer, Explorer.ExchangeRates, store: :none

config :explorer, Explorer.ExchangeRates.Source,
  source: Explorer.ExchangeRates.Source.NoOpSource,
  price_source: Explorer.ExchangeRates.Source.NoOpPriceSource
