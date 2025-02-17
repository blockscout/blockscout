import Config

# Configures the database
config :explorer, Explorer.Repo,
  prepare: :unnamed,
  timeout: :timer.seconds(60),
  migration_lock: nil,
  ssl_opts: [verify: :verify_none]

for repo <- [
      # Configures API the database
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
  config :explorer, repo,
    prepare: :unnamed,
    timeout: :timer.seconds(60),
    ssl_opts: [verify: :verify_none]
end

config :explorer, Explorer.Tracer, env: "production", disabled?: true

config :logger, :explorer,
  level: :info,
  path: Path.absname("logs/prod/explorer.log"),
  rotate: %{max_bytes: 52_428_800, keep: 19}

config :logger, :reading_token_functions,
  level: :debug,
  path: Path.absname("logs/prod/explorer/tokens/reading_functions.log"),
  metadata_filter: [fetcher: :token_functions],
  rotate: %{max_bytes: 52_428_800, keep: 19}

config :logger, :token_instances,
  level: :debug,
  path: Path.absname("logs/prod/explorer/tokens/token_instances.log"),
  metadata_filter: [fetcher: :token_instances],
  rotate: %{max_bytes: 52_428_800, keep: 19}
