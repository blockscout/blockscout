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

config :block_scout_web, BlockScoutWeb.HealthEndpoint,
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
queue_target = ConfigHelper.parse_integer_env_var("DATABASE_QUEUE_TARGET", 50)

# Configures the database
config :explorer, Explorer.Repo,
  url: System.get_env("DATABASE_URL"),
  listener_url: System.get_env("DATABASE_EVENT_URL"),
  pool_size: pool_size,
  ssl: ExplorerConfigHelper.ssl_enabled?(),
  queue_target: queue_target

# Configures API the database
config :explorer, Explorer.Repo.Replica1,
  url: ExplorerConfigHelper.get_api_db_url(),
  pool_size: ConfigHelper.parse_integer_env_var("POOL_SIZE_API", 50),
  ssl: ExplorerConfigHelper.ssl_enabled?(),
  queue_target: queue_target

# Configures Account database
config :explorer, Explorer.Repo.Account,
  url: ExplorerConfigHelper.get_account_db_url(),
  pool_size: ConfigHelper.parse_integer_env_var("ACCOUNT_POOL_SIZE", 50),
  ssl: ExplorerConfigHelper.ssl_enabled?(),
  queue_target: queue_target

# Configures Mud database
config :explorer, Explorer.Repo.Mud,
  url: ExplorerConfigHelper.get_mud_db_url(),
  pool_size: ConfigHelper.parse_integer_env_var("MUD_POOL_SIZE", 50),
  ssl: ExplorerConfigHelper.ssl_enabled?(),
  queue_target: queue_target

# Configures Suave database
config :explorer, Explorer.Repo.Suave,
  url: ExplorerConfigHelper.get_suave_db_url(),
  pool_size: 1,
  ssl: ExplorerConfigHelper.ssl_enabled?()

# Actually the following repos are not started, and its pool size remains
# unused. Separating repos for different chain type or feature flag is
# implemented only for the sake of keeping DB schema update relevant to the
# current chain type
for repo <- [
      # Feature dependent repos
      Explorer.Repo.BridgedTokens,
      Explorer.Repo.ShrunkInternalTransactions,

      # Chain-type dependent repos
      Explorer.Repo.Arbitrum,
      Explorer.Repo.Beacon,
      Explorer.Repo.Blackfort,
      Explorer.Repo.Celo,
      Explorer.Repo.Filecoin,
      Explorer.Repo.Optimism,
      Explorer.Repo.PolygonEdge,
      Explorer.Repo.PolygonZkevm,
      Explorer.Repo.RSK,
      Explorer.Repo.Scroll,
      Explorer.Repo.Shibarium,
      Explorer.Repo.Stability,
      Explorer.Repo.Zilliqa,
      Explorer.Repo.ZkSync,
      Explorer.Repo.Neon
    ] do
  config :explorer, repo,
    url: System.get_env("DATABASE_URL"),
    pool_size: 1,
    ssl: ExplorerConfigHelper.ssl_enabled?()
end

variant = Variant.get()

Code.require_file("#{variant}.exs", "apps/explorer/config/prod")

###############
### Indexer ###
###############

Code.require_file("#{variant}.exs", "apps/indexer/config/prod")
