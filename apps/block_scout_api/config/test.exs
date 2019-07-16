use Mix.Config

config :block_scout_api, BlockScoutApi.Endpoint,
  http: [port: 4003],
  secret_key_base: "27Swe6KtEtmN37WyEYRjKWyxYULNtrxlkCEKur4qoV+Lwtk8lafsR16ifz1XBBYj",
  server: true

config :logger, :block_scout_api,
  level: :warn,
  path: Path.absname("logs/test/block_scout_api.log")

config :explorer, Explorer.ExchangeRates, enabled: false, store: :none

config :explorer, Explorer.KnownTokens, enabled: false, store: :none

config :block_scout_api, :sql_sandbox, true
