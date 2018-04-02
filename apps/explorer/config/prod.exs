use Mix.Config

# Configures the database
config :explorer, Explorer.Repo,
  adapter: Ecto.Adapters.Postgres,
  url: System.get_env("DATABASE_URL"),
  pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
  ssl: String.equivalent?(System.get_env("ECTO_USE_SSL") || "true", "true"),
  prepare: :unnamed,
  timeout: 60_000,
  pool_timeout: 60_000

# Configure Web3
config :ethereumex, url: System.get_env("ETHEREUM_URL")

# Configure Quantum
config :explorer, Explorer.Scheduler,
  jobs: [
    [
      schedule: {:extended, System.get_env("EXQ_BALANCE_SCHEDULE") || "0 * * * * *"},
      task: {Explorer.Workers.RefreshBalance, :perform_later, []}
    ],
    [
      schedule: {:extended, System.get_env("EXQ_LATEST_BLOCK_SCHEDULE") || "* * * * * *"},
      task: {Explorer.Workers.ImportBlock, :perform_later, ["latest"]}
    ],
    [
      schedule: {:extended, System.get_env("EXQ_PENDING_BLOCK_SCHEDULE") || "* * * * * *"},
      task: {Explorer.Workers.ImportBlock, :perform_later, ["pending"]}
    ],
    [
      schedule: {:extended, System.get_env("EXQ_BACKFILL_SCHEDULE") || "* * * * * *"},
      task:
        {Explorer.Workers.ImportSkippedBlocks, :perform_later,
         [String.to_integer(System.get_env("EXQ_BACKFILL_BATCH_SIZE") || "1")]}
    ]
  ]

# Configure Exq
config :exq,
  node_identifier: Explorer.ExqNodeIdentifier,
  url: System.get_env("REDIS_URL"),
  queues: [
    {"blocks", String.to_integer(System.get_env("EXQ_BLOCKS_CONCURRENCY") || "1")},
    {"default", String.to_integer(System.get_env("EXQ_CONCURRENCY") || "1")},
    {"internal_transactions",
     String.to_integer(System.get_env("EXQ_INTERNAL_TRANSACTIONS_CONCURRENCY") || "1")},
    {"receipts", String.to_integer(System.get_env("EXQ_RECEIPTS_CONCURRENCY") || "1")},
    {"transactions", String.to_integer(System.get_env("EXQ_TRANSACTIONS_CONCURRENCY") || "1")}
  ]
