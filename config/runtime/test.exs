import Config

alias EthereumJSONRPC.Variant

######################
### BlockScout Web ###
######################

config :block_scout_web, BlockScoutWeb.CsvExportController, itx_export_enabled: true

########################
### Ethereum JSONRPC ###
########################

################
### Explorer ###
################

variant = Variant.get()

Code.require_file("#{variant}.exs", "#{__DIR__}/../../apps/explorer/config/test")

###############
### Indexer ###
###############

Code.require_file("#{variant}.exs", "#{__DIR__}/../../apps/indexer/config/test")
