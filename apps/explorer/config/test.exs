use Mix.Config

# Lower hashing rounds for faster tests
config :bcrypt_elixir, log_rounds: 4

# Configure your database
config :explorer, Explorer.Repo,
  adapter: Ecto.Adapters.Postgres,
  database: "explorer_test",
  hostname: "localhost",
  pool: Ecto.Adapters.SQL.Sandbox,
  # Default of `5_000` was too low for `BlockFetcher` test
  pool_timeout: 10_000,
  ownership_timeout: 60_000

config :explorer, Explorer.ExchangeRates, enabled: false

config :explorer, Explorer.Market.History.Cataloger, enabled: false
config :explorer, Explorer.Counters.TransactionCounter, enabled: false

config :logger, :explorer,
  level: :warn,
  path: Path.absname("logs/test/explorer.log")

if File.exists?(file = "test.secret.exs") do
  import_config file
end

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
