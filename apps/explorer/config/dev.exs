use Mix.Config

database = if System.get_env("DATABASE_URL"), do: nil, else: "explorer_dev"
hostname = if System.get_env("DATABASE_URL"), do: nil, else: "localhost"

# Configure your database
config :explorer, Explorer.Repo,
  database: database,
  hostname: hostname,
  url: System.get_env("DATABASE_URL"),
  pool_size: String.to_integer(System.get_env("POOL_SIZE", "50")),
  timeout: :timer.seconds(80),
  queue_target: 2000

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
    "parity"
  else
    System.get_env("ETHEREUM_JSONRPC_VARIANT")
    |> String.split(".")
    |> List.last()
    |> String.downcase()
  end

# Import variant specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "dev/#{variant}.exs"
