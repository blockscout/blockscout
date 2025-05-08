defmodule RPCTranslatorForwarder do
  @moduledoc """
  Phoenix router limits forwarding,
  so this module is to forward old paths for backward compatibility
  """
  alias BlockScoutWeb.API.RPC.RPCTranslator
  defdelegate init(opts), to: RPCTranslator
  defdelegate call(conn, opts), to: RPCTranslator
end

defmodule BlockScoutWeb.Routers.ApiRouter do
  @moduledoc """
  Router for API
  """
  use BlockScoutWeb, :router
  use BlockScoutWeb.Routers.ChainTypeScope

  use Utils.CompileTimeEnvHelper,
    chain_type: [:explorer, :chain_type],
    graphql_enabled: [:block_scout_web, [Api.GraphQL, :enabled]],
    graphql_max_complexity: [:block_scout_web, [Api.GraphQL, :max_complexity]],
    graphql_token_limit: [:block_scout_web, [Api.GraphQL, :token_limit]],
    reading_enabled: [:block_scout_web, [__MODULE__, :reading_enabled]],
    writing_enabled: [:block_scout_web, [__MODULE__, :writing_enabled]]

  use Utils.RuntimeEnvHelper,
    mud_enabled?: [:explorer, [Explorer.Chain.Mud, :enabled]]

  alias BlockScoutWeb.Routers.{
    AddressBadgesApiV2Router,
    APIKeyV2Router,
    SmartContractsApiV2Router,
    TokensApiV2Router,
    UtilsApiV2Router
  }

  alias BlockScoutWeb.Plug.{CheckApiV2, CheckFeature}
  alias BlockScoutWeb.Routers.AccountRouter

  @max_query_string_length 5_000

  forward("/v2/smart-contracts", SmartContractsApiV2Router)
  forward("/v2/tokens", TokensApiV2Router)

  forward("/v2/key", APIKeyV2Router)
  forward("/v2/utils", UtilsApiV2Router)
  forward("/v2/scam-badge-addresses", AddressBadgesApiV2Router)

  pipeline :api do
    plug(
      Plug.Parsers,
      parsers: [:urlencoded, :multipart, :json],
      length: 20_000_000,
      query_string_length: @max_query_string_length,
      pass: ["*/*"],
      json_decoder: Poison
    )

    plug(BlockScoutWeb.Plug.Logger, application: :api)
    plug(:accepts, ["json"])
    plug(:fetch_cookies)
  end

  pipeline :api_v2 do
    plug(
      Plug.Parsers,
      parsers: [:urlencoded, :multipart, :json],
      query_string_length: @max_query_string_length,
      pass: ["*/*"],
      json_decoder: Poison
    )

    plug(BlockScoutWeb.Plug.Logger, application: :api_v2)
    plug(:accepts, ["json"])
    plug(CheckApiV2)
    plug(:fetch_session)
    plug(:protect_from_forgery)
  end

  pipeline :api_v2_no_session do
    plug(
      Plug.Parsers,
      parsers: [:urlencoded, :multipart, :json],
      query_string_length: @max_query_string_length,
      pass: ["*/*"],
      json_decoder: Poison
    )

    plug(BlockScoutWeb.Plug.Logger, application: :api_v2)
    plug(:accepts, ["json"])
    plug(CheckApiV2)
  end

  pipeline :api_v1_graphql do
    plug(
      Plug.Parsers,
      parsers: [:json, Absinthe.Plug.Parser],
      json_decoder: Poison,
      body_reader: {BlockScoutWeb.GraphQL.BodyReader, :read_body, []}
    )

    plug(BlockScoutWeb.Plug.Logger, application: :api)
    plug(:accepts, ["json"])
    plug(BlockScoutWeb.Plug.GraphQLSchemaIntrospection)
  end

  pipeline :mud do
    plug(CheckFeature, feature_check: &mud_enabled?/0)
  end

  alias BlockScoutWeb.API.V2

  forward("/account", AccountRouter)

  scope "/v2/import" do
    pipe_through(:api_v2_no_session)

    post("/token-info", V2.ImportController, :import_token_info)
    delete("/token-info", V2.ImportController, :delete_token_info)

    get("/smart-contracts/:address_hash_param", V2.ImportController, :try_to_search_contract)

    if @chain_type == :optimism do
      post("/optimism/interop/", V2.OptimismController, :interop_import)
    end
  end

  scope "/v2", as: :api_v2 do
    pipe_through(:api_v2)

    scope "/search" do
      get("/", V2.SearchController, :search)
      get("/check-redirect", V2.SearchController, :check_redirect)
      get("/quick", V2.SearchController, :quick_search)
    end

    scope "/config" do
      get("/backend-version", V2.ConfigController, :backend_version)
      get("/csv-export", V2.ConfigController, :csv_export)
      get("/public-metrics", V2.ConfigController, :public_metrics)
    end

    scope "/transactions" do
      get("/", V2.TransactionController, :transactions)
      get("/watchlist", V2.TransactionController, :watchlist_transactions)
      get("/stats", V2.TransactionController, :stats)

      if @chain_type == :polygon_zkevm do
        get("/zkevm-batch/:batch_number", V2.TransactionController, :polygon_zkevm_batch)
      end

      if @chain_type == :zksync do
        get("/zksync-batch/:batch_number", V2.TransactionController, :zksync_batch)
      end

      if @chain_type == :arbitrum do
        get("/arbitrum-batch/:batch_number", V2.TransactionController, :arbitrum_batch)
      end

      if @chain_type == :optimism do
        get("/optimism-batch/:batch_number", V2.TransactionController, :optimism_batch)
      end

      if @chain_type == :scroll do
        get("/scroll-batch/:batch_number", V2.TransactionController, :scroll_batch)
      end

      if @chain_type == :suave do
        get("/execution-node/:execution_node_hash_param", V2.TransactionController, :execution_node)
      end

      get("/:transaction_hash_param", V2.TransactionController, :transaction)
      get("/:transaction_hash_param/token-transfers", V2.TransactionController, :token_transfers)
      get("/:transaction_hash_param/internal-transactions", V2.TransactionController, :internal_transactions)
      get("/:transaction_hash_param/logs", V2.TransactionController, :logs)
      get("/:transaction_hash_param/raw-trace", V2.TransactionController, :raw_trace)
      get("/:transaction_hash_param/state-changes", V2.TransactionController, :state_changes)
      get("/:transaction_hash_param/summary", V2.TransactionController, :summary)

      chain_scope :neon do
        get("/:transaction_hash_param/external-transactions", V2.TransactionController, :external_transactions)
      end

      if @chain_type == :ethereum do
        get("/:transaction_hash_param/blobs", V2.TransactionController, :blobs)
      end
    end

    scope "/token-transfers" do
      get("/", V2.TokenTransferController, :token_transfers)
    end

    scope "/internal-transactions" do
      get("/", V2.InternalTransactionController, :internal_transactions)
    end

    scope "/blocks" do
      get("/", V2.BlockController, :blocks)
      get("/:block_hash_or_number", V2.BlockController, :block)
      get("/:block_hash_or_number/transactions", V2.BlockController, :transactions)
      get("/:block_hash_or_number/internal-transactions", V2.BlockController, :internal_transactions)
      get("/:block_hash_or_number/withdrawals", V2.BlockController, :withdrawals)

      if @chain_type == :arbitrum do
        get("/arbitrum-batch/:batch_number", V2.BlockController, :arbitrum_batch)
      end

      if @chain_type == :celo do
        get("/:block_hash_or_number/epoch", V2.BlockController, :celo_epoch)
        get("/:block_hash_or_number/election-rewards/:reward_type", V2.BlockController, :celo_election_rewards)
      end

      if @chain_type == :optimism do
        get("/optimism-batch/:batch_number", V2.BlockController, :optimism_batch)
      end

      if @chain_type == :scroll do
        get("/scroll-batch/:batch_number", V2.BlockController, :scroll_batch)
      end
    end

    scope "/addresses" do
      get("/", V2.AddressController, :addresses_list)
      get("/:address_hash_param", V2.AddressController, :address)
      get("/:address_hash_param/tabs-counters", V2.AddressController, :tabs_counters)
      get("/:address_hash_param/counters", V2.AddressController, :counters)
      get("/:address_hash_param/token-balances", V2.AddressController, :token_balances)
      get("/:address_hash_param/tokens", V2.AddressController, :tokens)
      get("/:address_hash_param/transactions", V2.AddressController, :transactions)
      get("/:address_hash_param/transactions/csv", V2.CsvExportController, :transactions_csv)
      get("/:address_hash_param/token-transfers", V2.AddressController, :token_transfers)
      get("/:address_hash_param/token-transfers/csv", V2.CsvExportController, :token_transfers_csv)
      get("/:address_hash_param/internal-transactions", V2.AddressController, :internal_transactions)
      get("/:address_hash_param/internal-transactions/csv", V2.CsvExportController, :internal_transactions_csv)
      get("/:address_hash_param/logs", V2.AddressController, :logs)
      get("/:address_hash_param/logs/csv", V2.CsvExportController, :logs_csv)
      get("/:address_hash_param/blocks-validated", V2.AddressController, :blocks_validated)
      get("/:address_hash_param/coin-balance-history", V2.AddressController, :coin_balance_history)
      get("/:address_hash_param/coin-balance-history-by-day", V2.AddressController, :coin_balance_history_by_day)
      get("/:address_hash_param/withdrawals", V2.AddressController, :withdrawals)
      get("/:address_hash_param/nft", V2.AddressController, :nft_list)
      get("/:address_hash_param/nft/collections", V2.AddressController, :nft_collections)

      if @chain_type == :celo do
        get("/:address_hash_param/election-rewards", V2.AddressController, :celo_election_rewards)
        get("/:address_hash_param/election-rewards/csv", V2.CsvExportController, :celo_election_rewards_csv)
      end
    end

    scope "/main-page" do
      get("/blocks", V2.MainPageController, :blocks)
      get("/transactions", V2.MainPageController, :transactions)
      get("/transactions/watchlist", V2.MainPageController, :watchlist_transactions)
      get("/indexing-status", V2.MainPageController, :indexing_status)

      if @chain_type == :optimism do
        get("/optimism-deposits", V2.MainPageController, :optimism_deposits)
      end

      if @chain_type == :polygon_zkevm do
        get("/zkevm/batches/confirmed", V2.PolygonZkevmController, :batches_confirmed)
        get("/zkevm/batches/latest-number", V2.PolygonZkevmController, :batch_latest_number)
      end

      if @chain_type == :zksync do
        get("/zksync/batches/confirmed", V2.ZkSyncController, :batches_confirmed)
        get("/zksync/batches/latest-number", V2.ZkSyncController, :batch_latest_number)
      end

      if @chain_type == :arbitrum do
        get("/arbitrum/messages/to-rollup", V2.ArbitrumController, :recent_messages_to_l2)
        get("/arbitrum/batches/committed", V2.ArbitrumController, :batches_committed)
        get("/arbitrum/batches/latest-number", V2.ArbitrumController, :batch_latest_number)
      end
    end

    scope "/stats" do
      get("/", V2.StatsController, :stats)

      scope "/charts" do
        get("/transactions", V2.StatsController, :transactions_chart)
        get("/market", V2.StatsController, :market_chart)
        get("/secondary-coin-market", V2.StatsController, :secondary_coin_market_chart)
      end
    end

    scope "/optimism" do
      if @chain_type == :optimism do
        get("/txn-batches", V2.OptimismController, :transaction_batches)
        get("/txn-batches/count", V2.OptimismController, :transaction_batches_count)
        get("/txn-batches/:l2_block_range_start/:l2_block_range_end", V2.OptimismController, :transaction_batches)
        get("/batches", V2.OptimismController, :batches)
        get("/batches/count", V2.OptimismController, :batches_count)
        get("/batches/da/celestia/:height/:commitment", V2.OptimismController, :batch_by_celestia_blob)
        get("/batches/:internal_id", V2.OptimismController, :batch_by_internal_id)
        get("/output-roots", V2.OptimismController, :output_roots)
        get("/output-roots/count", V2.OptimismController, :output_roots_count)
        get("/deposits", V2.OptimismController, :deposits)
        get("/deposits/count", V2.OptimismController, :deposits_count)
        get("/withdrawals", V2.OptimismController, :withdrawals)
        get("/withdrawals/count", V2.OptimismController, :withdrawals_count)
        get("/games", V2.OptimismController, :games)
        get("/games/count", V2.OptimismController, :games_count)
        get("/interop/messages", V2.OptimismController, :interop_messages)
        get("/interop/messages/count", V2.OptimismController, :interop_messages_count)
        get("/interop/public-key", V2.OptimismController, :interop_public_key)
      end
    end

    scope "/polygon-edge" do
      chain_scope :polygon_edge do
        get("/deposits", V2.PolygonEdgeController, :deposits)
        get("/deposits/count", V2.PolygonEdgeController, :deposits_count)
        get("/withdrawals", V2.PolygonEdgeController, :withdrawals)
        get("/withdrawals/count", V2.PolygonEdgeController, :withdrawals_count)
      end
    end

    scope "/scroll" do
      if @chain_type == :scroll do
        get("/batches", V2.ScrollController, :batches)
        get("/batches/count", V2.ScrollController, :batches_count)
        get("/batches/:number", V2.ScrollController, :batch)
        get("/deposits", V2.ScrollController, :deposits)
        get("/deposits/count", V2.ScrollController, :deposits_count)
        get("/withdrawals", V2.ScrollController, :withdrawals)
        get("/withdrawals/count", V2.ScrollController, :withdrawals_count)
      end
    end

    scope "/shibarium" do
      chain_scope :shibarium do
        get("/deposits", V2.ShibariumController, :deposits)
        get("/deposits/count", V2.ShibariumController, :deposits_count)
        get("/withdrawals", V2.ShibariumController, :withdrawals)
        get("/withdrawals/count", V2.ShibariumController, :withdrawals_count)
      end
    end

    scope "/withdrawals" do
      get("/", V2.WithdrawalController, :withdrawals_list)
      get("/counters", V2.WithdrawalController, :withdrawals_counters)
    end

    scope "/zkevm" do
      if @chain_type == :polygon_zkevm do
        get("/batches", V2.PolygonZkevmController, :batches)
        get("/batches/count", V2.PolygonZkevmController, :batches_count)
        get("/batches/:batch_number", V2.PolygonZkevmController, :batch)
        get("/deposits", V2.PolygonZkevmController, :deposits)
        get("/deposits/count", V2.PolygonZkevmController, :deposits_count)
        get("/withdrawals", V2.PolygonZkevmController, :withdrawals)
        get("/withdrawals/count", V2.PolygonZkevmController, :withdrawals_count)
      end
    end

    scope "/proxy" do
      scope "/3dparty" do
        get("/:platform_id", V2.Proxy.UniversalProxyController, :index)

        scope "/noves-fi" do
          get("/transactions/:transaction_hash_param", V2.Proxy.NovesFiController, :transaction)

          get("/addresses/:address_hash_param/transactions", V2.Proxy.NovesFiController, :address_transactions)

          get("/transaction-descriptions", V2.Proxy.NovesFiController, :describe_transactions)
        end

        scope "/xname" do
          get("/addresses/:address_hash_param", V2.Proxy.XnameController, :address)
        end

        scope "/solidityscan" do
          get("/smart-contracts/:address_hash/report", V2.SmartContractController, :solidityscan_report)
        end
      end

      scope "/account-abstraction" do
        get("/operations/:operation_hash_param", V2.Proxy.AccountAbstractionController, :operation)
        get("/operations/:operation_hash_param/summary", V2.Proxy.AccountAbstractionController, :summary)
        get("/bundlers/:address_hash_param", V2.Proxy.AccountAbstractionController, :bundler)
        get("/bundlers", V2.Proxy.AccountAbstractionController, :bundlers)
        get("/factories/:address_hash_param", V2.Proxy.AccountAbstractionController, :factory)
        get("/factories", V2.Proxy.AccountAbstractionController, :factories)
        get("/paymasters/:address_hash_param", V2.Proxy.AccountAbstractionController, :paymaster)
        get("/paymasters", V2.Proxy.AccountAbstractionController, :paymasters)
        get("/accounts/:address_hash_param", V2.Proxy.AccountAbstractionController, :account)
        get("/accounts", V2.Proxy.AccountAbstractionController, :accounts)
        get("/bundles", V2.Proxy.AccountAbstractionController, :bundles)
        get("/operations", V2.Proxy.AccountAbstractionController, :operations)
        get("/status", V2.Proxy.AccountAbstractionController, :status)
      end

      scope "/metadata" do
        get("/addresses", V2.Proxy.MetadataController, :addresses)
      end
    end

    scope "/blobs" do
      if @chain_type == :ethereum do
        get("/:blob_hash_param", V2.BlobController, :blob)
      end
    end

    scope "/validators" do
      if @chain_type == :zilliqa do
        scope "/zilliqa" do
          get("/", V2.ValidatorController, :zilliqa_validators_list)
          get("/:bls_public_key", V2.ValidatorController, :zilliqa_validator)
        end
      end

      chain_scope :stability do
        scope "/stability" do
          get("/", V2.ValidatorController, :stability_validators_list)
          get("/counters", V2.ValidatorController, :stability_validators_counters)
        end
      end

      chain_scope :blackfort do
        scope "/blackfort" do
          get("/", V2.ValidatorController, :blackfort_validators_list)
          get("/counters", V2.ValidatorController, :blackfort_validators_counters)
        end
      end
    end

    scope "/zksync" do
      if @chain_type == :zksync do
        get("/batches", V2.ZkSyncController, :batches)
        get("/batches/count", V2.ZkSyncController, :batches_count)
        get("/batches/:batch_number", V2.ZkSyncController, :batch)
      end
    end

    scope "/mud" do
      pipe_through(:mud)
      get("/worlds", V2.MudController, :worlds)
      get("/worlds/count", V2.MudController, :worlds_count)
      get("/worlds/:world/tables", V2.MudController, :world_tables)
      get("/worlds/:world/systems", V2.MudController, :world_systems)
      get("/worlds/:world/systems/:system", V2.MudController, :world_system)
      get("/worlds/:world/tables/count", V2.MudController, :world_tables_count)
      get("/worlds/:world/tables/:table_id/records", V2.MudController, :world_table_records)
      get("/worlds/:world/tables/:table_id/records/count", V2.MudController, :world_table_records_count)
      get("/worlds/:world/tables/:table_id/records/:record_id", V2.MudController, :world_table_record)
    end

    scope "/arbitrum" do
      if @chain_type == :arbitrum do
        get("/messages/:direction", V2.ArbitrumController, :messages)
        get("/messages/:direction/count", V2.ArbitrumController, :messages_count)
        get("/messages/claim/:message_id", V2.ArbitrumController, :claim_message)
        get("/messages/withdrawals/:transaction_hash", V2.ArbitrumController, :withdrawals)
        get("/batches", V2.ArbitrumController, :batches)
        get("/batches/count", V2.ArbitrumController, :batches_count)
        get("/batches/:batch_number", V2.ArbitrumController, :batch)
        get("/batches/da/anytrust/:data_hash", V2.ArbitrumController, :batch_by_data_availability_info)

        get(
          "/batches/da/celestia/:height/:transaction_commitment",
          V2.ArbitrumController,
          :batch_by_data_availability_info
        )
      end
    end

    scope "/advanced-filters" do
      get("/", V2.AdvancedFilterController, :list)
      get("/csv", V2.AdvancedFilterController, :list_csv)
      get("/methods", V2.AdvancedFilterController, :list_methods)
    end
  end

  scope "/v1/graphql" do
    pipe_through(:api_v1_graphql)

    if @graphql_enabled do
      forward("/", Absinthe.Plug,
        schema: BlockScoutWeb.GraphQL.Schema,
        analyze_complexity: true,
        max_complexity: @graphql_max_complexity,
        token_limit: @graphql_token_limit
      )
    end
  end

  scope "/v1", as: :api_v1 do
    pipe_through(:api)
    alias BlockScoutWeb.API.{EthRPC, RPC, V1}
    alias BlockScoutWeb.API.V1.GasPriceOracleController
    alias BlockScoutWeb.API.V2.SearchController

    # leave the same endpoint in v1 in order to keep backward compatibility
    get("/search", SearchController, :search)

    if @chain_type == :celo do
      get("/celo-election-rewards-csv", V2.CsvExportController, :celo_election_rewards_csv)
    end

    get("/gas-price-oracle", GasPriceOracleController, :gas_price_oracle)

    if @reading_enabled do
      get("/supply", V1.SupplyController, :supply)
      post("/eth-rpc", EthRPC.EthController, :eth_request)
    end

    if @writing_enabled do
      post("/verified_smart_contracts", V1.VerifiedSmartContractController, :create)
    end

    if @reading_enabled do
      forward("/", RPC.RPCTranslator, %{
        "block" => {RPC.BlockController, []},
        "account" => {RPC.AddressController, []},
        "logs" => {RPC.LogsController, []},
        "token" => {RPC.TokenController, []},
        "stats" => {RPC.StatsController, []},
        "contract" => {RPC.ContractController, [:verify]},
        "transaction" => {RPC.TransactionController, []}
      })
    end
  end

  scope "/health" do
    get("/", BlockScoutWeb.API.HealthController, :health)
    get("/liveness", BlockScoutWeb.API.HealthController, :liveness)
    get("/readiness", BlockScoutWeb.API.HealthController, :readiness)
    get("/multichain-search-export", BlockScoutWeb.API.HealthController, :multichain_search_db_export)
  end

  scope "/" do
    pipe_through(:api)
    alias BlockScoutWeb.API.{EthRPC, RPC}

    if @reading_enabled do
      post("/eth-rpc", EthRPC.EthController, :eth_request)

      forward("/", RPCTranslatorForwarder, %{
        "block" => {RPC.BlockController, []},
        "account" => {RPC.AddressController, []},
        "logs" => {RPC.LogsController, []},
        "token" => {RPC.TokenController, []},
        "stats" => {RPC.StatsController, []},
        "contract" => {RPC.ContractController, [:verify]},
        "transaction" => {RPC.TransactionController, []}
      })
    end
  end
end
