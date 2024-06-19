import Config

# Configure your database
config :explorer, Explorer.Repo,
  timeout: :timer.seconds(80),
  migration_lock: nil

# Configure API database
config :explorer, Explorer.Repo.Replica1, timeout: :timer.seconds(80)

# Configure Account database
config :explorer, Explorer.Repo.Account, timeout: :timer.seconds(80)

# Configure Optimism database
config :explorer, Explorer.Repo.Optimism, timeout: :timer.seconds(80)

# Configure Polygon Edge database
config :explorer, Explorer.Repo.PolygonEdge, timeout: :timer.seconds(80)

# Configure Polygon zkEVM database
config :explorer, Explorer.Repo.PolygonZkevm, timeout: :timer.seconds(80)

# Configure ZkSync database
config :explorer, Explorer.Repo.ZkSync, timeout: :timer.seconds(80)

config :explorer, Explorer.Repo.Celo, timeout: :timer.seconds(80)

config :explorer, Explorer.Repo.RSK, timeout: :timer.seconds(80)

config :explorer, Explorer.Repo.Shibarium, timeout: :timer.seconds(80)

config :explorer, Explorer.Repo.Suave, timeout: :timer.seconds(80)

config :explorer, Explorer.Repo.Beacon, timeout: :timer.seconds(80)

# Configure Arbitrum database
config :explorer, Explorer.Repo.Arbitrum, timeout: :timer.seconds(80)

config :explorer, Explorer.Repo.BridgedTokens, timeout: :timer.seconds(80)

config :explorer, Explorer.Repo.Filecoin, timeout: :timer.seconds(80)

config :explorer, Explorer.Repo.Stability, timeout: :timer.seconds(80)

config :explorer, Explorer.Repo.Mud, timeout: :timer.seconds(80)

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
