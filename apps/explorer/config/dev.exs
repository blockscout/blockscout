import Config

# Configure your database
config :explorer, Explorer.Repo.Local, timeout: :timer.seconds(80)

# Configure API database
config :explorer, Explorer.Repo.Replica1, timeout: :timer.seconds(80)

# Configure Account database
config :explorer, Explorer.Repo.Account, timeout: :timer.seconds(80)

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

config :explorer, Explorer.Celo.CoreContracts, enabled: true, refresh: :timer.hours(1)
config :explorer, Explorer.Celo.AddressCache, Explorer.Celo.CoreContracts
