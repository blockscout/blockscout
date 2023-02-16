# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.
import Config

# General application configuration
config :explorer,
  ecto_repos: [Explorer.Repo, Explorer.Repo.Account],
  token_functions_reader_max_retries: 3,
  # for not fully indexed blockchains
  decode_not_a_contract_calls: System.get_env("DECODE_NOT_A_CONTRACT_CALLS") == "true"

config :explorer, Explorer.Counters.AverageBlockTime,
  enabled: true,
  period: :timer.minutes(10)

config :explorer, Explorer.ChainSpec.GenesisData, enabled: true

config :explorer, Explorer.Chain.Cache.BlockNumber, enabled: true

config :explorer, Explorer.Chain.Cache.AddressSum,
  enabled: true,
  ttl_check_interval: :timer.seconds(1)

config :explorer, Explorer.Chain.Cache.AddressSumMinusBurnt,
  enabled: true,
  ttl_check_interval: :timer.seconds(1)

cache_address_with_balances_update_interval = System.get_env("CACHE_ADDRESS_WITH_BALANCES_UPDATE_INTERVAL")

balances_update_interval =
  if cache_address_with_balances_update_interval do
    case Integer.parse(cache_address_with_balances_update_interval) do
      {integer, ""} -> integer
      _ -> nil
    end
  end

config :explorer, Explorer.Counters.AddressesWithBalanceCounter,
  enabled: false,
  enable_consolidation: true,
  update_interval_in_seconds: balances_update_interval || 30 * 60

config :explorer, Explorer.Counters.AddressesCounter,
  enabled: true,
  enable_consolidation: true,
  update_interval_in_seconds: balances_update_interval || 30 * 60

config :explorer, Explorer.Counters.AddressTransactionsGasUsageCounter,
  enabled: true,
  enable_consolidation: true

config :explorer, Explorer.Counters.AddressTokenUsdSum,
  enabled: true,
  enable_consolidation: true

config :explorer, Explorer.Chain.Cache.ContractsCounter,
  enabled: true,
  enable_consolidation: true,
  update_interval_in_seconds: 30 * 60

config :explorer, Explorer.Chain.Cache.NewContractsCounter,
  enabled: true,
  enable_consolidation: true,
  update_interval_in_seconds: 30 * 60

config :explorer, Explorer.Chain.Cache.VerifiedContractsCounter,
  enabled: true,
  enable_consolidation: true,
  update_interval_in_seconds: 30 * 60

config :explorer, Explorer.Chain.Cache.NewVerifiedContractsCounter,
  enabled: true,
  enable_consolidation: true,
  update_interval_in_seconds: 30 * 60

config :explorer, Explorer.ExchangeRates.TokenExchangeRates,
  enabled: true

config :explorer, Explorer.Counters.TokenHoldersCounter,
  enabled: true,
  enable_consolidation: true

config :explorer, Explorer.Counters.TokenTransfersCounter,
  enabled: true,
  enable_consolidation: true

config :explorer, Explorer.Counters.AddressTransactionsCounter,
  enabled: true,
  enable_consolidation: true

config :explorer, Explorer.Counters.AddressTokenTransfersCounter,
  enabled: true,
  enable_consolidation: true

config :explorer, Explorer.Counters.BlockBurnedFeeCounter,
  enabled: true,
  enable_consolidation: true

config :explorer, Explorer.Counters.BlockPriorityFeeCounter,
  enabled: true,
  enable_consolidation: true

config :explorer, Explorer.TokenTransferTokenIdMigration.Supervisor, enabled: true

config :explorer, Explorer.Chain.Fetcher.CheckBytecodeMatchingOnDemand, enabled: true

config :explorer, Explorer.Chain.Fetcher.FetchValidatorInfoOnDemand, enabled: true

config :explorer, Explorer.Chain.Cache.GasUsage,
  enabled: System.get_env("CACHE_ENABLE_TOTAL_GAS_USAGE_COUNTER") == "true"

config :explorer, Explorer.Integrations.EctoLogger, query_time_ms_threshold: :timer.seconds(2)

config :explorer, Explorer.Tags.AddressTag.Cataloger, enabled: true

config :explorer, Explorer.Chain.Cache.MinMissingBlockNumber, enabled: System.get_env("DISABLE_WRITE_API") != "true"

config :explorer, Explorer.Repo, migration_timestamps: [type: :utc_datetime_usec]

config :explorer, Explorer.Tracer,
  service: :explorer,
  adapter: SpandexDatadog.Adapter,
  trace_key: :blockscout

config :explorer,
  solc_bin_api_url: "https://solc-bin.ethereum.org"

config :explorer, :http_adapter, HTTPoison

config :logger, :explorer,
  # keep synced with `config/config.exs`
  format: "$dateT$time $metadata[$level] $message\n",
  metadata:
    ~w(application fetcher request_id first_block_number last_block_number missing_block_range_count missing_block_count
       block_number step count error_count shrunk import_id transaction_id)a,
  metadata_filter: [application: :explorer]

config :spandex_ecto, SpandexEcto.EctoLogger,
  service: :ecto,
  tracer: Explorer.Tracer,
  otp_app: :explorer

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
