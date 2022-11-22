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

variant = Variant.get()

Code.require_file("#{variant}.exs", "apps/explorer/config/test")

###############
### Indexer ###
###############

Code.require_file("#{variant}.exs", "apps/indexer/config/test")
