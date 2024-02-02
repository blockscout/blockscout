import Config

alias EthereumJSONRPC.Variant
alias Explorer.Repo.ConfigHelper, as: ExplorerConfigHelper

######################
### BlockScout Web ###
######################

config :block_scout_web, BlockScoutWeb.Endpoint,
  secret_key_base: System.get_env("SECRET_KEY_BASE"),
  check_origin: System.get_env("CHECK_ORIGIN", "false") == "true" || false,
  http: [port: System.get_env("PORT")],
  url: [
    scheme: System.get_env("BLOCKSCOUT_PROTOCOL") || "https",
    port: System.get_env("PORT"),
    host: System.get_env("BLOCKSCOUT_HOST") || "localhost"
  ]

########################
### Ethereum JSONRPC ###
########################

################
### Explorer ###
################

pool_size =
  if System.get_env("DATABASE_READ_ONLY_API_URL"),
    do: ConfigHelper.parse_integer_env_var("POOL_SIZE", 50),
    else: ConfigHelper.parse_integer_env_var("POOL_SIZE", 40)

# Configures the database
config :explorer, Explorer.Repo,
  url: System.get_env("DATABASE_URL"),
  pool_size: pool_size,
  ssl: ExplorerConfigHelper.ssl_enabled?()

pool_size_api =
  if System.get_env("DATABASE_READ_ONLY_API_URL"),
    do: ConfigHelper.parse_integer_env_var("POOL_SIZE_API", 50),
    else: ConfigHelper.parse_integer_env_var("POOL_SIZE_API", 10)

# Configures API the database
config :explorer, Explorer.Repo.Replica1,
  url: ExplorerConfigHelper.get_api_db_url(),
  pool_size: pool_size_api,
  ssl: ExplorerConfigHelper.ssl_enabled?()

# Configures Account database
config :explorer, Explorer.Repo.Account,
  url: ExplorerConfigHelper.get_account_db_url(),
  pool_size: ConfigHelper.parse_integer_env_var("ACCOUNT_POOL_SIZE", 50),
  ssl: ExplorerConfigHelper.ssl_enabled?()

variant = Variant.get()

Code.require_file("#{variant}.exs", "apps/explorer/config/prod")

###############
### Indexer ###
###############

Code.require_file("#{variant}.exs", "apps/indexer/config/prod")
