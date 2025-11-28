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

# Disable on-demand internal transaction fetcher in tests
# (the indexer module is not available in explorer tests)
config :explorer, :on_demand_internal_transaction_fetcher, nil

config :explorer, Explorer.Chain.Cache.Counters.Transactions24hCount,
  cache_period: ConfigHelper.parse_time_env_var("CACHE_TRANSACTIONS_24H_STATS_PERIOD", "1h"),
  enable_consolidation: false

variant = Variant.get()

Code.require_file("#{variant}.exs", "apps/explorer/config/test")

###############
### Indexer ###
###############

Code.require_file("#{variant}.exs", "apps/indexer/config/test")
