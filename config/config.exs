# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
import Config

# By default, the umbrella project as well as each child
# application will require this configuration file, ensuring
# they all use the same configuration. While one could
# configure all applications here, we prefer to delegate
# back to each application for organization purposes.
for config <- "../apps/*/config/config.exs" |> Path.expand(__DIR__) |> Path.wildcard() do
  import_config config
end

config :phoenix, :json_library, Jason

config :logger,
  backends: [
    # all applications and all levels
    :console,
    # all applications, but only errors
    {LoggerFileBackend, :error},
    # only :ecto, but all levels
    {LoggerFileBackend, :ecto},
    # only :block_scout_web, but all levels
    {LoggerFileBackend, :block_scout_web},
    # only :ethereum_jsonrpc, but all levels
    {LoggerFileBackend, :ethereum_jsonrpc},
    # only :explorer, but all levels
    {LoggerFileBackend, :explorer},
    # only :indexer, but all levels
    {LoggerFileBackend, :indexer},
    {LoggerFileBackend, :indexer_token_balances},
    {LoggerFileBackend, :token_instances},
    {LoggerFileBackend, :reading_token_functions},
    {LoggerFileBackend, :pending_transactions_to_refetch},
    {LoggerFileBackend, :empty_blocks_to_refetch},
    {LoggerFileBackend, :api},
    {LoggerFileBackend, :block_import_timings},
    {LoggerFileBackend, :account}
  ]

config :logger, :console,
  # Use same format for all loggers, even though the level should only ever be `:error` for `:error` backend
  format: "$dateT$time $metadata[$level] $message\n",
  metadata:
    ~w(application fetcher request_id first_block_number last_block_number missing_block_range_count missing_block_count
       block_number step count error_count shrunk import_id transaction_id)a

config :logger, :ecto,
  # Use same format for all loggers, even though the level should only ever be `:error` for `:error` backend
  format: "$dateT$time $metadata[$level] $message\n",
  metadata:
    ~w(application fetcher request_id first_block_number last_block_number missing_block_range_count missing_block_count
       block_number step count error_count shrunk import_id transaction_id)a,
  metadata_filter: [application: :ecto]

config :logger, :error,
  # Use same format for all loggers, even though the level should only ever be `:error` for `:error` backend
  format: "$dateT$time $metadata[$level] $message\n",
  level: :error,
  metadata:
    ~w(application fetcher request_id first_block_number last_block_number missing_block_range_count missing_block_count
       block_number step count error_count shrunk import_id transaction_id)a

# config :ethereumex, url: System.get_env("FAUCET_JSONRPC_HTTP_URL")

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
