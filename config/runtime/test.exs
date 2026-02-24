import Config

alias EthereumJSONRPC.Variant

######################
### BlockScout Web ###
######################

config :block_scout_web, BlockScoutWeb.API.V2, enabled: true

########################
### Ethereum JSONRPC ###
########################

################
### Explorer ###
################

# Enable Oban for async CSV export controller tests (testing: :manual from config/test.exs
# ensures jobs are not auto-executed)
config :explorer, Oban,
  enabled: true,
  queues: [csv_export: 1, csv_export_sanitize: 1]

config :explorer, Explorer.Chain.Cache.Counters.Transactions24hCount,
  cache_period: ConfigHelper.parse_time_env_var("CACHE_TRANSACTIONS_24H_STATS_PERIOD", "1h"),
  enable_consolidation: false

variant = Variant.get()

Code.require_file("#{variant}.exs", "apps/explorer/config/test")

###############
### Indexer ###
###############

Code.require_file("#{variant}.exs", "apps/indexer/config/test")
