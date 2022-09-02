import Config

######################
### BlockScout Web ###
######################

port =
  case System.get_env("PORT") && Integer.parse(System.get_env("PORT")) do
    {port, _} -> port
    :error -> nil
    nil -> nil
  end

config :block_scout_web, BlockScoutWeb.Endpoint,
  secret_key_base:
    System.get_env("SECRET_KEY_BASE") || "RMgI4C1HSkxsEjdhtGMfwAHfyT6CKWXOgzCboJflfSm4jeAlic52io05KB6mqzc5",
  http: [
    port: port || 4000
  ],
  url: [
    scheme: "http",
    host: System.get_env("BLOCKSCOUT_HOST") || "localhost",
    path: System.get_env("NETWORK_PATH") || "/",
    api_path: System.get_env("API_PATH") || "/"
  ],
  https: [
    port: (port && port + 1) || 4001,
    cipher_suite: :strong,
    certfile: System.get_env("CERTFILE") || "priv/cert/selfsigned.pem",
    keyfile: System.get_env("KEYFILE") || "priv/cert/selfsigned_key.pem"
  ]

########################
### Ethereum JSONRPC ###
########################

################
### Explorer ###
################

database = if System.get_env("DATABASE_URL"), do: nil, else: "explorer_dev"
hostname = if System.get_env("DATABASE_URL"), do: nil, else: "localhost"

database_api_url =
  if System.get_env("DATABASE_READ_ONLY_API_URL"),
    do: System.get_env("DATABASE_READ_ONLY_API_URL"),
    else: System.get_env("DATABASE_URL")

# pool_size =
#   if System.get_env("DATABASE_READ_ONLY_API_URL"),
#     do: String.to_integer(System.get_env("POOL_SIZE", "40")),
#     else: String.to_integer(System.get_env("POOL_SIZE", "50"))
pool_size = String.to_integer(System.get_env("POOL_SIZE", "30"))

# Configure your database
config :explorer, Explorer.Repo,
  database: database,
  hostname: hostname,
  url: System.get_env("DATABASE_URL"),
  pool_size: pool_size

database_api = if System.get_env("DATABASE_READ_ONLY_API_URL"), do: nil, else: database
hostname_api = if System.get_env("DATABASE_READ_ONLY_API_URL"), do: nil, else: hostname

pool_size_api =
  if System.get_env("DATABASE_READ_ONLY_API_URL"),
    do: String.to_integer(System.get_env("POOL_SIZE_API", "10")),
    else: String.to_integer(System.get_env("POOL_SIZE_API", "10"))

# Configure API database
config :explorer, Explorer.Repo.Replica1,
  database: database_api,
  hostname: hostname_api,
  url: database_api_url,
  pool_size: pool_size_api

database_account_url = System.get_env("DATABASE_ACCOUNT_URL") || System.get_env("DATABASE_URL")

pool_size_account =
  if System.get_env("DATABASE_ACCOUNT_URL"),
    do: String.to_integer(System.get_env("POOL_SIZE_ACCOUNT", "10")),
    else: String.to_integer(System.get_env("POOL_SIZE_ACCOUNT", "10"))

database_account = if System.get_env("DATABASE_ACCOUNT_URL"), do: nil, else: database
hostname_account = if System.get_env("DATABASE_ACCOUNT_URL"), do: nil, else: hostname

# Configure Account database
config :explorer, Explorer.Repo.Account,
  database: database_account,
  hostname: hostname_account,
  url: database_account_url,
  pool_size: pool_size_account

variant =
  if is_nil(System.get_env("ETHEREUM_JSONRPC_VARIANT")) do
    "ganache"
  else
    System.get_env("ETHEREUM_JSONRPC_VARIANT")
    |> String.split(".")
    |> List.last()
    |> String.downcase()
  end

Code.require_file("#{variant}.exs", "apps/explorer/config/dev")

###############
### Indexer ###
###############

Code.require_file("#{variant}.exs", "apps/indexer/config/dev")
