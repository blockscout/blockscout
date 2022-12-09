import Config

######################
### BlockScout Web ###
######################

########################
### Ethereum JSONRPC ###
########################

################
### Explorer ###
################

variant =
  if is_nil(System.get_env("ETHEREUM_JSONRPC_VARIANT")) do
    "parity"
  else
    System.get_env("ETHEREUM_JSONRPC_VARIANT")
    |> String.split(".")
    |> List.last()
    |> String.downcase()
  end

Code.require_file("#{variant}.exs", "#{__DIR__}/../../apps/explorer/config/test")

###############
### Indexer ###
###############

Code.require_file("#{variant}.exs", "#{__DIR__}/../../apps/indexer/config/test")
