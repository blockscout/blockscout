use Mix.Config

# Print only warnings and errors during test
config :logger, level: :warn

config :explorer, Explorer.ExchangeRates, source: Explorer.ExchangeRates.Source.TestSource
