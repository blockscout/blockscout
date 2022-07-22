import Config

config :indexer, Indexer.Tracer, env: "dev", disabled?: true

config :logger, :indexer,
  level: :debug,
  path: Path.absname("logs/dev/indexer.log")

config :logger, :indexer_token_balances,
  level: :debug,
  path: Path.absname("logs/dev/indexer/token_balances/error.log"),
  metadata_filter: [fetcher: :token_balances]

config :logger, :failed_contract_creations,
  level: :debug,
  path: Path.absname("logs/dev/indexer/failed_contract_creations.log"),
  metadata_filter: [fetcher: :failed_created_addresses]

config :logger, :addresses_without_code,
  level: :debug,
  path: Path.absname("logs/dev/indexer/addresses_without_code.log"),
  metadata_filter: [fetcher: :addresses_without_code]

config :logger, :pending_transactions_to_refetch,
  level: :debug,
  path: Path.absname("logs/dev/indexer/pending_transactions_to_refetch.log"),
  metadata_filter: [fetcher: :pending_transactions_to_refetch]

config :logger, :empty_blocks_to_refetch,
  level: :debug,
  path: Path.absname("logs/dev/indexer/empty_blocks_to_refetch.log"),
  metadata_filter: [fetcher: :empty_blocks_to_refetch]

config :logger, :block_import_timings,
  level: :debug,
  path: Path.absname("logs/dev/indexer/block_import_timings.log"),
  metadata_filter: [fetcher: :block_import_timings]

variant =
  if is_nil(System.get_env("ETHEREUM_JSONRPC_VARIANT")) do
    "ganache"
  else
    System.get_env("ETHEREUM_JSONRPC_VARIANT")
    |> String.split(".")
    |> List.last()
    |> String.downcase()
  end

# Import variant specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "dev/#{variant}.exs"
