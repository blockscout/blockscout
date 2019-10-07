# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.
use Mix.Config

# General application configuration
config :explorer,
  ecto_repos: [Explorer.Repo],
  coin: System.get_env("COIN") || "POA",
  token_functions_reader_max_retries: 3,
  allowed_evm_versions:
    System.get_env("ALLOWED_EVM_VERSIONS") ||
      "homestead,tangerineWhistle,spuriousDragon,byzantium,constantinople,petersburg,default",
  include_uncles_in_average_block_time:
    if(System.get_env("UNCLES_IN_AVERAGE_BLOCK_TIME") == "true", do: true, else: false),
  healthy_blocks_period: System.get_env("HEALTHY_BLOCKS_PERIOD") || :timer.minutes(5)

average_block_period =
  case Integer.parse(System.get_env("AVERAGE_BLOCK_CACHE_PERIOD", "")) do
    {secs, ""} -> :timer.seconds(secs)
    _ -> :timer.minutes(30)
  end

config :explorer, Explorer.Counters.AverageBlockTime,
  enabled: true,
  period: average_block_period

config :explorer, Explorer.ChainSpec.GenesisData,
  enabled: true,
  chain_spec_path: System.get_env("CHAIN_SPEC_PATH"),
  emission_format: System.get_env("EMISSION_FORMAT", "DEFAULT"),
  rewards_contract_address: System.get_env("REWARDS_CONTRACT_ADDRESS", "0xeca443e8e1ab29971a45a9c57a6a9875701698a5")

config :explorer, Explorer.Chain.Cache.BlockNumber,
  enabled: true,
  ttl_check_interval: if(System.get_env("DISABLE_INDEXER") == "true", do: :timer.seconds(1), else: false),
  global_ttl: if(System.get_env("DISABLE_INDEXER") == "true", do: :timer.seconds(5))

balances_update_interval =
  if System.get_env("ADDRESS_WITH_BALANCES_UPDATE_INTERVAL") do
    case Integer.parse(System.get_env("ADDRESS_WITH_BALANCES_UPDATE_INTERVAL")) do
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

config :explorer, Explorer.ExchangeRates, enabled: true, store: :ets

config :explorer, Explorer.KnownTokens, enabled: true, store: :ets

config :explorer, Explorer.Integrations.EctoLogger, query_time_ms_threshold: :timer.seconds(2)

config :explorer, Explorer.Market.History.Cataloger, enabled: System.get_env("DISABLE_INDEXER") != "true"

config :explorer, Explorer.Repo, migration_timestamps: [type: :utc_datetime_usec]

config :explorer, Explorer.Tracer,
  service: :explorer,
  adapter: SpandexDatadog.Adapter,
  trace_key: :blockscout

if System.get_env("METADATA_CONTRACT") && System.get_env("VALIDATORS_CONTRACT") do
  config :explorer, Explorer.Validator.MetadataRetriever,
    metadata_contract_address: System.get_env("METADATA_CONTRACT"),
    validators_contract_address: System.get_env("VALIDATORS_CONTRACT")

  config :explorer, Explorer.Validator.MetadataProcessor, enabled: System.get_env("DISABLE_INDEXER") != "true"
else
  config :explorer, Explorer.Validator.MetadataProcessor, enabled: false
end

config :explorer, Explorer.Staking.PoolsReader,
  validators_contract_address: System.get_env("POS_VALIDATORS_CONTRACT"),
  staking_contract_address: System.get_env("POS_STAKING_CONTRACT")

if System.get_env("POS_STAKING_CONTRACT") do
  config :explorer, Explorer.Staking.EpochCounter,
    enabled: true,
    staking_contract_address: System.get_env("POS_STAKING_CONTRACT")
else
  config :explorer, Explorer.Staking.EpochCounter, enabled: false
end

case System.get_env("SUPPLY_MODULE") do
  "TokenBridge" ->
    config :explorer, supply: Explorer.Chain.Supply.TokenBridge

  "rsk" ->
    config :explorer, supply: Explorer.Chain.Supply.RSK

  _ ->
    :ok
end

if System.get_env("SOURCE_MODULE") == "TokenBridge" do
  config :explorer, Explorer.ExchangeRates.Source, source: Explorer.ExchangeRates.Source.TokenBridge
end

config :explorer,
  solc_bin_api_url: "https://solc-bin.ethereum.org",
  checksum_function: System.get_env("CHECKSUM_FUNCTION") && String.to_atom(System.get_env("CHECKSUM_FUNCTION"))

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

market_history_cache_period =
  case Integer.parse(System.get_env("MARKET_HISTORY_CACHE_PERIOD", "")) do
    {secs, ""} -> :timer.seconds(secs)
    _ -> :timer.hours(6)
  end

config :explorer, Explorer.Market.MarketHistoryCache, period: market_history_cache_period

config :explorer, Explorer.Chain.Cache.Blocks,
  ttl_check_interval: if(System.get_env("DISABLE_INDEXER") == "true", do: :timer.seconds(1), else: false),
  global_ttl: if(System.get_env("DISABLE_INDEXER") == "true", do: :timer.seconds(5))

config :explorer, Explorer.Chain.Cache.Transactions,
  ttl_check_interval: if(System.get_env("DISABLE_INDEXER") == "true", do: :timer.seconds(1), else: false),
  global_ttl: if(System.get_env("DISABLE_INDEXER") == "true", do: :timer.seconds(5))

config :explorer, Explorer.Chain.Cache.Accounts,
  ttl_check_interval: if(System.get_env("DISABLE_INDEXER") == "true", do: :timer.seconds(1), else: false),
  global_ttl: if(System.get_env("DISABLE_INDEXER") == "true", do: :timer.seconds(5))

config :explorer, Explorer.Chain.Cache.PendingTransactions,
  ttl_check_interval: if(System.get_env("DISABLE_INDEXER") == "true", do: :timer.seconds(1), else: false),
  global_ttl: if(System.get_env("DISABLE_INDEXER") == "true", do: :timer.seconds(5))

config :explorer, Explorer.Chain.Cache.Uncles,
  ttl_check_interval: if(System.get_env("DISABLE_INDEXER") == "true", do: :timer.seconds(1), else: false),
  global_ttl: if(System.get_env("DISABLE_INDEXER") == "true", do: :timer.seconds(5))

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
