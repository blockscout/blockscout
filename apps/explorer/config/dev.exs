import Config

database = if System.get_env("DATABASE_URL"), do: nil, else: "explorer_dev"
hostname = if System.get_env("DATABASE_URL"), do: nil, else: "localhost"
username = if System.get_env("DATABASE_URL"), do: nil, else: "postgres"

database_api_url =
  if System.get_env("DATABASE_READ_ONLY_API_URL"),
    do: System.get_env("DATABASE_READ_ONLY_API_URL"),
    else: System.get_env("DATABASE_URL")

# Configure your database
config :explorer, Explorer.Repo,
  database: database,
  hostname: hostname,
  username: username,
  url: System.get_env("DATABASE_URL"),
  pool_size: String.to_integer(System.get_env("POOL_SIZE", "50")),
  timeout: :timer.seconds(80)

database_api = if System.get_env("DATABASE_READ_ONLY_API_URL"), do: nil, else: database
hostname_api = if System.get_env("DATABASE_READ_ONLY_API_URL"), do: nil, else: hostname

# Configure API database
config :explorer, Explorer.Repo.Replica1,
  database: database_api,
  hostname: hostname_api,
  url: database_api_url,
  pool_size: String.to_integer(System.get_env("POOL_SIZE_API", "50")),
  timeout: :timer.seconds(80)

config :explorer, Explorer.Tracer, env: "dev", disabled?: true

config :logger, :explorer,
  level: :debug,
  path: Path.absname("logs/dev/explorer.log")

config :logger, :reading_token_functions,
  level: :debug,
  path: Path.absname("logs/dev/explorer/tokens/reading_functions.log"),
  metadata_filter: [fetcher: :token_functions]

config :logger, :token_instances,
  level: :debug,
  path: Path.absname("logs/dev/explorer/tokens/token_instances.log"),
  metadata_filter: [fetcher: :token_instances]

variant =
  if is_nil(System.get_env("ETHEREUM_JSONRPC_VARIANT")) do
    "ganache"
  else
    System.get_env("ETHEREUM_JSONRPC_VARIANT")
    |> String.split(".")
    |> List.last()
    |> String.downcase()
  end

config :explorer, Explorer.Celo.CoreContracts, enabled: true, refresh: :timer.hours(1)
config :explorer, Explorer.Celo.AddressCache, Explorer.Celo.CoreContracts

# Import variant specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "dev/#{variant}.exs"
