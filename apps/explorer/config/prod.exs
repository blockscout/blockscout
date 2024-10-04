import Config

# Configures the database
config :explorer, Explorer.Repo,
  prepare: :unnamed,
  timeout: :timer.seconds(60),
  migration_lock: nil,
  ssl_opts: [verify: :verify_none]

# Configures API the database
config :explorer, Explorer.Repo.Replica1,
  prepare: :unnamed,
  timeout: :timer.seconds(60),
  ssl_opts: [verify: :verify_none]

# Configures Account database
config :explorer, Explorer.Repo.Account,
  prepare: :unnamed,
  timeout: :timer.seconds(60),
  ssl_opts: [verify: :verify_none]

config :explorer, Explorer.Repo.Optimism,
  prepare: :unnamed,
  timeout: :timer.seconds(60),
  ssl_opts: [verify: :verify_none]

config :explorer, Explorer.Repo.PolygonEdge,
  prepare: :unnamed,
  timeout: :timer.seconds(60),
  ssl_opts: [verify: :verify_none]

config :explorer, Explorer.Repo.PolygonZkevm,
  prepare: :unnamed,
  timeout: :timer.seconds(60),
  ssl_opts: [verify: :verify_none]

config :explorer, Explorer.Repo.ZkSync,
  prepare: :unnamed,
  timeout: :timer.seconds(60),
  ssl_opts: [verify: :verify_none]

config :explorer, Explorer.Repo.Celo,
  prepare: :unnamed,
  timeout: :timer.seconds(60),
  ssl_opts: [verify: :verify_none]

config :explorer, Explorer.Repo.RSK,
  prepare: :unnamed,
  timeout: :timer.seconds(60),
  ssl_opts: [verify: :verify_none]

config :explorer, Explorer.Repo.Shibarium,
  prepare: :unnamed,
  timeout: :timer.seconds(60),
  ssl_opts: [verify: :verify_none]

config :explorer, Explorer.Repo.Suave,
  prepare: :unnamed,
  timeout: :timer.seconds(60),
  ssl_opts: [verify: :verify_none]

config :explorer, Explorer.Repo.Beacon,
  prepare: :unnamed,
  timeout: :timer.seconds(60),
  ssl_opts: [verify: :verify_none]

config :explorer, Explorer.Repo.Arbitrum,
  prepare: :unnamed,
  timeout: :timer.seconds(60),
  ssl_opts: [verify: :verify_none]

config :explorer, Explorer.Repo.BridgedTokens,
  prepare: :unnamed,
  timeout: :timer.seconds(60),
  ssl_opts: [verify: :verify_none]

config :explorer, Explorer.Repo.Filecoin,
  prepare: :unnamed,
  timeout: :timer.seconds(60),
  ssl_opts: [verify: :verify_none]

config :explorer, Explorer.Repo.Stability,
  prepare: :unnamed,
  timeout: :timer.seconds(60),
  ssl_opts: [verify: :verify_none]

config :explorer, Explorer.Repo.Mud,
  prepare: :unnamed,
  timeout: :timer.seconds(60),
  ssl_opts: [verify: :verify_none]

config :explorer, Explorer.Repo.ShrunkInternalTransactions,
  prepare: :unnamed,
  timeout: :timer.seconds(60),
  ssl_opts: [verify: :verify_none]

config :explorer, Explorer.Repo.Blackfort,
  prepare: :unnamed,
  timeout: :timer.seconds(60),
  ssl_opts: [verify: :verify_none]

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
