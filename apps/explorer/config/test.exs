use Mix.Config

# Lower hashing rounds for faster tests
config :bcrypt_elixir, log_rounds: 4

# Configure your database
config :explorer, Explorer.Repo,
  database: "explorer_test",
  hostname: "localhost",
  pool: Ecto.Adapters.SQL.Sandbox,
  # Default of `5_000` was too low for `BlockFetcher` test
  ownership_timeout: :timer.minutes(1)

config :explorer, Explorer.ExchangeRates, enabled: false, store: :ets

config :explorer, Explorer.Counters.AddressesWithBalanceCounter, enabled: false, enable_consolidation: false

config :explorer, Explorer.Counters.BlockValidationCounter, enabled: false, enable_consolidation: true

config :explorer, Explorer.Counters.BlockValidationCounter, enabled: false, enable_consolidation: false

config :explorer, Explorer.Counters.TokenHoldersCounter, enabled: false, enable_consolidation: false

config :explorer, Explorer.Market.History.Cataloger, enabled: false

config :explorer, Explorer.Tracer, disabled?: false

config :logger, :explorer,
  level: :warn,
  path: Path.absname("logs/test/explorer.log")

secret_file =
  __ENV__.file
  |> Path.dirname()
  |> Path.join("test.secret.exs")

if File.exists?(secret_file) do
  import_config secret_file
end

config :explorer, Explorer.ExchangeRates.Source.TransactionAndLog,
  secondary_source: Explorer.ExchangeRates.Source.OneCoinSource

variant =
  if is_nil(System.get_env("ETHEREUM_JSONRPC_VARIANT")) do
    "parity"
  else
    System.get_env("ETHEREUM_JSONRPC_VARIANT")
    |> String.split(".")
    |> List.last()
    |> String.downcase()
  end

# Import variant specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "test/#{variant}.exs"
