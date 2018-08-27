use Mix.Config

# Print only warnings and errors during test
config :logger, :console, level: :warn

config :explorer, Explorer.ExchangeRates,
  source: Explorer.ExchangeRates.Source.NoOpSource,
  store: :none
