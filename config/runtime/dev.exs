import Config

alias EthereumJSONRPC.Variant
alias Explorer.Repo.ConfigHelper

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
    port: port || 4000,
    protocol_options: [idle_timeout: 300_000]
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

pool_size =
  if System.get_env("DATABASE_READ_ONLY_API_URL"),
    do: ConfigHelper.get_db_pool_size("30"),
    else: ConfigHelper.get_db_pool_size("40")

# Configure your database
config :explorer, Explorer.Repo,
  database: database,
  hostname: hostname,
  url: System.get_env("DATABASE_URL"),
  pool_size: pool_size

database_api = if System.get_env("DATABASE_READ_ONLY_API_URL"), do: nil, else: database
hostname_api = if System.get_env("DATABASE_READ_ONLY_API_URL"), do: nil, else: hostname

# Configure API database
config :explorer, Explorer.Repo.Replica1,
  database: database_api,
  hostname: hostname_api,
  url: ConfigHelper.get_api_db_url(),
  pool_size: ConfigHelper.get_api_db_pool_size("10")

database_account = if System.get_env("ACCOUNT_DATABASE_URL"), do: nil, else: database
hostname_account = if System.get_env("ACCOUNT_DATABASE_URL"), do: nil, else: hostname

# Configure Account database
config :explorer, Explorer.Repo.Account,
  database: database_account,
  hostname: hostname_account,
  url: ConfigHelper.get_account_db_url(),
  pool_size: ConfigHelper.get_account_db_pool_size("10")

variant = Variant.get()

Code.require_file("#{variant}.exs", "apps/explorer/config/dev")

###############
### Indexer ###
###############

Code.require_file("#{variant}.exs", "apps/indexer/config/dev")
