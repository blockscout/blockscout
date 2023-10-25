import Config

alias EthereumJSONRPC.Variant
alias Explorer.Repo.ConfigHelper, as: ExplorerConfigHelper

######################
### BlockScout Web ###
######################

port = ExplorerConfigHelper.get_port()

config :block_scout_web, BlockScoutWeb.Endpoint,
  secret_key_base: System.get_env("SECRET_KEY_BASE"),
  check_origin: System.get_env("CHECK_ORIGIN", "false") == "true" || false,
  http: [port: port],
  url: [
    scheme: System.get_env("BLOCKSCOUT_PROTOCOL") || "https",
    port: port,
    host: System.get_env("BLOCKSCOUT_HOST") || "localhost"
  ]

########################
### Ethereum JSONRPC ###
########################

################
### Explorer ###
################

pool_size = ConfigHelper.parse_integer_env_var("POOL_SIZE", 50)

# Configures the database
config :explorer, Explorer.Repo,
  url: System.get_env("DATABASE_URL"),
  pool_size: pool_size,
  ssl: ExplorerConfigHelper.ssl_enabled?()

# Configures API the database
config :explorer, Explorer.Repo.Replica1,
  url: ExplorerConfigHelper.get_api_db_url(),
  pool_size: ConfigHelper.parse_integer_env_var("POOL_SIZE_API", 50),
  ssl: ExplorerConfigHelper.ssl_enabled?()

# Configures Account database
config :explorer, Explorer.Repo.Account,
  url: ExplorerConfigHelper.get_account_db_url(),
  pool_size: ConfigHelper.parse_integer_env_var("ACCOUNT_POOL_SIZE", 50),
  ssl: ExplorerConfigHelper.ssl_enabled?()

# Configures PolygonEdge database
config :explorer, Explorer.Repo.PolygonEdge,
  url: System.get_env("DATABASE_URL"),
  # actually this repo is not started, and its pool size remains unused.
  # separating repos for different CHAIN_TYPE is implemented only for the sake of keeping DB schema update relevant to the current chain type
  pool_size: 1,
  ssl: ExplorerConfigHelper.ssl_enabled?()

# Configures PolygonZkevm database
config :explorer, Explorer.Repo.PolygonZkevm,
  url: System.get_env("DATABASE_URL"),
  # actually this repo is not started, and its pool size remains unused.
  # separating repos for different CHAIN_TYPE is implemented only for the sake of keeping DB schema update relevant to the current chain type
  pool_size: 1,
  ssl: ExplorerConfigHelper.ssl_enabled?()

# Configures Rootstock database
config :explorer, Explorer.Repo.RSK,
  url: System.get_env("DATABASE_URL"),
  # actually this repo is not started, and its pool size remains unused.
  # separating repos for different CHAIN_TYPE is implemented only for the sake of keeping DB schema update relevant to the current chain type
  pool_size: 1,
  ssl: ExplorerConfigHelper.ssl_enabled?()

# Configures Suave database
config :explorer, Explorer.Repo.Suave,
  url: ExplorerConfigHelper.get_suave_db_url(),
  pool_size: 1,
  ssl: ExplorerConfigHelper.ssl_enabled?()

variant = Variant.get()

Code.require_file("#{variant}.exs", "apps/explorer/config/prod")

###############
### Indexer ###
###############

Code.require_file("#{variant}.exs", "apps/indexer/config/prod")
