import Config

config :explorer, Explorer.ExchangeRates, enabled: false, store: :ets, fetch_btc_value: true

config :explorer, Explorer.Chain.Cache.BlockNumber, enabled: false

config :explorer, Explorer.KnownTokens, enabled: false, store: :ets

config :explorer, Explorer.Counters.AverageBlockTime, enabled: false

config :explorer, Explorer.Counters.AddressesWithBalanceCounter, enabled: false, enable_consolidation: false

# This historian is a GenServer whose init uses a Repo in a Task process.
# This causes a ConnectionOwnership error
config :explorer, Explorer.Chain.Transaction.History.Historian, enabled: false
config :explorer, Explorer.Market.History.Historian, enabled: false

config :explorer, Explorer.Counters.AddressesCounter, enabled: false, enable_consolidation: false

config :explorer, Explorer.Market.History.Cataloger, enabled: false

config :explorer, Explorer.Tracer, disabled?: false

config :explorer,
  realtime_events_sender: Explorer.Chain.Events.SimpleSender

variant =
  if is_nil(System.get_env("ETHEREUM_JSONRPC_VARIANT")) do
    "parity"
  else
    System.get_env("ETHEREUM_JSONRPC_VARIANT")
    |> String.split(".")
    |> List.last()
    |> String.downcase()
  end

Code.require_file("#{variant}.exs", "#{__DIR__}/../../../explorer/config/test")
Code.require_file("#{variant}.exs", "#{__DIR__}/../../../indexer/config/test")
