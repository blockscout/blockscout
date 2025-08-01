import Config

alias EthereumJSONRPC.Variant
alias Explorer.Repo.ConfigHelper, as: ExplorerConfigHelper

######################
### BlockScout Web ###
######################

port = ExplorerConfigHelper.get_port()

config :block_scout_web, BlockScoutWeb.Endpoint,
  secret_key_base:
    System.get_env("SECRET_KEY_BASE") || "RMgI4C1HSkxsEjdhtGMfwAHfyT6CKWXOgzCboJflfSm4jeAlic52io05KB6mqzc5",
  http: [
    port: port
  ],
  url: [
    scheme: "http",
    host: System.get_env("BLOCKSCOUT_HOST", "localhost")
  ],
  https: [
    port: port + 1,
    cipher_suite: :strong,
    certfile: System.get_env("CERTFILE") || "priv/cert/selfsigned.pem",
    keyfile: System.get_env("KEYFILE") || "priv/cert/selfsigned_key.pem"
  ]

config :block_scout_web, BlockScoutWeb.HealthEndpoint,
  secret_key_base:
    System.get_env("SECRET_KEY_BASE") || "RMgI4C1HSkxsEjdhtGMfwAHfyT6CKWXOgzCboJflfSm4jeAlic52io05KB6mqzc5",
  http: [
    port: port
  ],
  url: [
    scheme: "http",
    host: System.get_env("BLOCKSCOUT_HOST", "localhost")
  ],
  https: [
    port: port + 1,
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
    do: ConfigHelper.parse_integer_env_var("POOL_SIZE", 30),
    else: ConfigHelper.parse_integer_env_var("POOL_SIZE", 40)

queue_target = ConfigHelper.parse_integer_env_var("DATABASE_QUEUE_TARGET", 50)

# Configure your database
config :explorer, Explorer.Repo,
  database: database,
  hostname: hostname,
  url: System.get_env("DATABASE_URL"),
  pool_size: pool_size,
  queue_target: queue_target

database_api = if System.get_env("DATABASE_READ_ONLY_API_URL"), do: nil, else: database
hostname_api = if System.get_env("DATABASE_READ_ONLY_API_URL"), do: nil, else: hostname

# Configure API database
config :explorer, Explorer.Repo.Replica1,
  database: database_api,
  hostname: hostname_api,
  url: ExplorerConfigHelper.get_api_db_url(),
  pool_size: ConfigHelper.parse_integer_env_var("POOL_SIZE_API", 10),
  queue_target: queue_target

database_account = if System.get_env("ACCOUNT_DATABASE_URL"), do: nil, else: database
hostname_account = if System.get_env("ACCOUNT_DATABASE_URL"), do: nil, else: hostname

# Configure Account database
config :explorer, Explorer.Repo.Account,
  database: database_account,
  hostname: hostname_account,
  url: ExplorerConfigHelper.get_account_db_url(),
  pool_size: ConfigHelper.parse_integer_env_var("ACCOUNT_POOL_SIZE", 10),
  queue_target: queue_target

database_mud = if System.get_env("MUD_DATABASE_URL"), do: nil, else: database
hostname_mud = if System.get_env("MUD_DATABASE_URL"), do: nil, else: hostname

# Configure MUD indexer database
config :explorer, Explorer.Repo.Mud,
  database: database_mud,
  hostname: hostname_mud,
  url: ExplorerConfigHelper.get_mud_db_url(),
  pool_size: ConfigHelper.parse_integer_env_var("MUD_POOL_SIZE", 10),
  queue_target: queue_target

# Configure Suave database
config :explorer, Explorer.Repo.Suave,
  database: database,
  hostname: hostname,
  url: ExplorerConfigHelper.get_suave_db_url(),
  pool_size: 1

# Actually the following repos are not started, and its pool size remains
# unused. Separating repos for different CHAIN_TYPE is implemented only for the
# sake of keeping DB schema update relevant to the current chain type
for repo <- [
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
      # Feature dependent repos
      Explorer.Repo.BridgedTokens,
      Explorer.Repo.ShrunkInternalTransactions,
      Explorer.Repo.Neon
    ] do
  config :explorer, repo,
    database: database,
    hostname: hostname,
    url: System.get_env("DATABASE_URL"),
    pool_size: 1
end

variant = Variant.get()

Code.require_file("#{variant}.exs", "apps/explorer/config/dev")

###############
### Indexer ###
###############

Code.require_file("#{variant}.exs", "apps/indexer/config/dev")
