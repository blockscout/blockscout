import Config

# Lower hashing rounds for faster tests
config :bcrypt_elixir, log_rounds: 4

# Configure your database
config :explorer, Explorer.Repo.Local,
  url: System.get_env("DATABASE_URL") || "postgresql://postgres:postgres@localhost:5432/explorer_test",
  database: "explorer_test",
  hostname: "localhost",
  password: "postgres",
  pool: Ecto.Adapters.SQL.Sandbox,
  # Default of `5_000` was too low for `BlockFetcher` test
  ownership_timeout: :timer.minutes(7),
  timeout: :timer.seconds(60),
  queue_target: 1000,
  priv: "priv/repo",
  # deactivate ecto logs for test output
  log: false

config :explorer, Explorer.ExchangeRates, enabled: false, store: :ets

config :explorer, Explorer.Chain.Cache.BlockNumber, enabled: false

config :explorer, Explorer.ChainSpec.GenesisData, enabled: false

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

config :explorer, Explorer.Staking.ContractState, enabled: false

config :explorer, Explorer.Chain.Cache.MinMissingBlockNumber, enabled: false

config :logger, :explorer,
  level: :warn,
  path: Path.absname("logs/test/explorer.log")

config :explorer, Explorer.ExchangeRates.Source.TransactionAndLog,
  secondary_source: Explorer.ExchangeRates.Source.OneCoinSource

config :explorer,
  realtime_events_sender: Explorer.Chain.Events.SimpleSender

config :explorer, Explorer.Chain.Events.Listener,
  enabled: true,
  event_source: Explorer.Chain.Events.PubSubSource

variant =
  if is_nil(System.get_env("ETHEREUM_JSONRPC_VARIANT")) do
    "parity"
  else
    System.get_env("ETHEREUM_JSONRPC_VARIANT")
    |> String.split(".")
    |> List.last()
    |> String.downcase()
  end

config :explorer, Explorer.Celo.CoreContracts, refresh: :timer.hours(1), refresh_concurrency: 2
config :explorer, Explorer.Celo.AddressCache, Explorer.Celo.AddressCache.Mock

# Import variant specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "test/#{variant}.exs"
