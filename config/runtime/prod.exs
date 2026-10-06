# SPDX-License-Identifier: LicenseRef-Blockscout
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
database_url = ConfigHelper.parse_url_env_var("DATABASE_URL")

# Postgrex prepared statements mode. With `named`, a query is a single round trip to the
# database (the parsed statement is cached per connection); `unnamed` needs two round trips
# per query (parse/describe, then bind/execute) but is required when connections go through a
# transaction-mode pooler (e.g. PgBouncer without `max_prepared_statements`).
prepare_modes = ["named", "unnamed"]
prepare_mode = ConfigHelper.parse_catalog_value("DATABASE_PREPARE_MODE", prepare_modes, true, "unnamed")

api_prepare_mode =
  ConfigHelper.parse_catalog_value("DATABASE_API_PREPARE_MODE", prepare_modes, true, Atom.to_string(prepare_mode))

# Configures the database
config :explorer,
       Explorer.Repo,
       [
         url: database_url,
         pool_size: pool_size,
         queue_target: queue_target,
         prepare: prepare_mode
       ]
       |> Keyword.merge(ExplorerConfigHelper.ssl_options(database_url))

api_db_url = ExplorerConfigHelper.get_api_db_url()

# Configures API the database
config :explorer,
       Explorer.Repo.Replica1,
       [
         url: api_db_url,
         pool_size: ConfigHelper.parse_integer_env_var("POOL_SIZE_API", 50),
         queue_target: queue_target,
         prepare: api_prepare_mode
       ]
       |> Keyword.merge(ExplorerConfigHelper.ssl_options(api_db_url))

account_db_url = ExplorerConfigHelper.get_account_db_url()

# Configures Account database
config :explorer,
       Explorer.Repo.Account,
       [
         url: account_db_url,
         pool_size: ConfigHelper.parse_integer_env_var("ACCOUNT_POOL_SIZE", 50),
         queue_target: queue_target
       ]
       |> Keyword.merge(ExplorerConfigHelper.ssl_options(account_db_url))

suave_db_url = ExplorerConfigHelper.get_suave_db_url()

# Configures Suave database
config :explorer,
       Explorer.Repo.Suave,
       [
         url: suave_db_url,
         pool_size: 1
       ]
       |> Keyword.merge(ExplorerConfigHelper.ssl_options(suave_db_url))

event_notification_db_url = ExplorerConfigHelper.get_event_notification_db_url()

config :explorer,
       Explorer.Repo.EventNotifications,
       [
         url: event_notification_db_url,
         pool_size: ConfigHelper.parse_integer_env_var("DATABASE_EVENT_POOL_SIZE", 10),
         queue_target: queue_target
       ]
       |> Keyword.merge(ExplorerConfigHelper.ssl_options(event_notification_db_url))

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
      Explorer.Repo.Eden,
      Explorer.Repo.Filecoin,
      Explorer.Repo.Optimism,
      Explorer.Repo.PolygonEdge,
      Explorer.Repo.RSK,
      Explorer.Repo.Scroll,
      Explorer.Repo.Shibarium,
      Explorer.Repo.Stability,
      Explorer.Repo.Zilliqa,
      Explorer.Repo.ZkSync,
      Explorer.Repo.Neon
    ] do
  config :explorer,
         repo,
         [
           url: database_url,
           pool_size: 1
         ]
         |> Keyword.merge(ExplorerConfigHelper.ssl_options(database_url))
end

variant = Variant.get()

Code.require_file("#{variant}.exs", "apps/explorer/config/prod")

###############
### Indexer ###
###############

Code.require_file("#{variant}.exs", "apps/indexer/config/prod")
