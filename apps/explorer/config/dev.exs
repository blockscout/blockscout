use Mix.Config

# Configure your database
config :explorer, Explorer.Repo,
  database: "explorer_dev",
  hostname: "localhost",
  pool_size: 20,
  timeout: 80_000

config :explorer, Explorer.Tracer, env: "dev", disabled?: true

config :logger, :explorer,
  level: :debug,
  path: Path.absname("logs/dev/explorer.log")

config :logger, :reading_token_functions,
  level: :debug,
  path: Path.absname("logs/dev/explorer/tokens/reading_functions.log"),
  metadata_filter: [fetcher: :token_functions]

import_config "dev.secret.exs"

variant =
  if is_nil(System.get_env("ETHEREUM_JSONRPC_VARIANT")) do
    "ganache"
  else
    System.get_env("ETHEREUM_JSONRPC_VARIANT")
    |> String.split(".")
    |> List.last()
    |> String.downcase()
  end

# Import variant specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "dev/#{variant}.exs"
