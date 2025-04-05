import Config

# Configure your database
config :explorer, Explorer.Repo,
  timeout: :timer.seconds(80),
  migration_lock: nil

for repo <- [
      # Configure API database
      Explorer.Repo.Replica1,

      # Feature dependent repos
      Explorer.Repo.Account,
      Explorer.Repo.BridgedTokens,
      Explorer.Repo.ShrunkInternalTransactions,

      # Chain-type dependent repos
      Explorer.Repo.Arbitrum,
      Explorer.Repo.Beacon,
      Explorer.Repo.Blackfort,
      Explorer.Repo.Celo,
      Explorer.Repo.Filecoin,
      Explorer.Repo.Mud,
      Explorer.Repo.Optimism,
      Explorer.Repo.PolygonEdge,
      Explorer.Repo.PolygonZkevm,
      Explorer.Repo.RSK,
      Explorer.Repo.Scroll,
      Explorer.Repo.Shibarium,
      Explorer.Repo.Stability,
      Explorer.Repo.Suave,
      Explorer.Repo.Zilliqa,
      Explorer.Repo.ZkSync,
      Explorer.Repo.Neon
    ] do
  config :explorer, repo, timeout: :timer.seconds(80)
end

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
