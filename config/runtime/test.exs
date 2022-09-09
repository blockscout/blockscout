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

Code.require_file("#{variant}.exs", "apps/explorer/config/test")

redis_port =
  case System.get_env("ACCOUNT_REDIS_PORT") && Integer.parse(System.get_env("ACCOUNT_REDIS_PORT")) do
    {port, _} -> port
    :error -> nil
    nil -> nil
  end

config :explorer, Redix,
  host: System.get_env("ACCOUNT_REDIS_HOST_URL") || "127.0.0.1",
  port: redis_port || 6379

###############
### Indexer ###
###############

Code.require_file("#{variant}.exs", "apps/indexer/config/test")
