import Config

# Configures the database
config :explorer, Explorer.Repo,
  prepare: :unnamed,
  timeout: :timer.seconds(60),
  migration_lock: nil

# Configures API the database
config :explorer, Explorer.Repo.Replica1,
  prepare: :unnamed,
  timeout: :timer.seconds(60),
  queue_target: 2000

# Configures Account database
config :explorer, Explorer.Repo.Account,
  prepare: :unnamed,
  timeout: :timer.seconds(60)

config :explorer, Explorer.Tracer, env: "production", disabled?: true

config :logger, :explorer,
  level: :debug,
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
