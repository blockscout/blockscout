import Config

config :indexer, Indexer.Tracer, env: "production", disabled?: true

config :logger, :indexer,
  level: :info,
  path: Path.absname("logs/prod/indexer.log"),
  rotate: %{max_bytes: 52_428_800, keep: 19}

config :logger, :indexer_token_balances,
  level: :debug,
  path: Path.absname("logs/prod/indexer/token_balances/error.log"),
  metadata_filter: [fetcher: :token_balances],
  rotate: %{max_bytes: 52_428_800, keep: 19}

config :logger, :failed_contract_creations,
  level: :debug,
  path: Path.absname("logs/prod/indexer/failed_contract_creations.log"),
  metadata_filter: [fetcher: :failed_created_addresses],
  rotate: %{max_bytes: 52_428_800, keep: 19}

config :logger, :addresses_without_code,
  level: :debug,
  path: Path.absname("logs/prod/indexer/addresses_without_code.log"),
  metadata_filter: [fetcher: :addresses_without_code],
  rotate: %{max_bytes: 52_428_800, keep: 19}

config :logger, :pending_transactions_to_refetch,
  level: :debug,
  path: Path.absname("logs/prod/indexer/pending_transactions_to_refetch.log"),
  metadata_filter: [fetcher: :pending_transactions_to_refetch],
  rotate: %{max_bytes: 52_428_800, keep: 19}

config :logger, :empty_blocks_to_refetch,
  level: :info,
  path: Path.absname("logs/prod/indexer/empty_blocks_to_refetch.log"),
  metadata_filter: [fetcher: :empty_blocks_to_refetch],
  rotate: %{max_bytes: 52_428_800, keep: 19}

config :logger, :block_import_timings,
  level: :debug,
  path: Path.absname("logs/prod/indexer/block_import_timings.log"),
  metadata_filter: [fetcher: :block_import_timings],
  rotate: %{max_bytes: 52_428_800, keep: 19}

config :logger, :withdrawal,
  level: :info,
  path: Path.absname("logs/dev/indexer/withdrawal.log"),
  metadata_filter: [fetcher: :withdrawal],
  rotate: %{max_bytes: 52_428_800, keep: 19}
