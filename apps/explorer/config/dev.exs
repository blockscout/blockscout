use Mix.Config

# Configure your database
config :explorer, Explorer.Repo,
  adapter: Ecto.Adapters.Postgres,
  database: "explorer_dev",
  hostname: "localhost",
  pool_size: 10

# Configure Quantum
config :explorer, Explorer.Scheduler,
  jobs: [
    [
      schedule: {:extended, "*/15 * * * * *"},
      task: {Explorer.Workers.RefreshBalance, :perform_later, []}
    ],
    [
      schedule: {:extended, "*/5 * * * * *"},
      task: {Explorer.Workers.ImportBlock, :perform_later, ["latest"]}
    ],
    [
      schedule: {:extended, "*/5 * * * * *"},
      task: {Explorer.Workers.ImportBlock, :perform_later, ["pending"]}
    ],
    [
      schedule: {:extended, "*/15 * * * * *"},
      task: {Explorer.Workers.ImportSkippedBlocks, :perform_later, [1]}
    ]
  ]

import_config "dev.secret.exs"
