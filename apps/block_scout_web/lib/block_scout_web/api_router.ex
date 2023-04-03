defmodule RPCTranslatorForwarder do
  @moduledoc """
  Phoenix router limits forwarding,
  so this module is to forward old paths for backward compatibility
  """
  alias BlockScoutWeb.API.RPC.RPCTranslator
  defdelegate init(opts), to: RPCTranslator
  defdelegate call(conn, opts), to: RPCTranslator
end

defmodule BlockScoutWeb.ApiRouter do
  @moduledoc """
  Router for API
  """
  use BlockScoutWeb, :router
  alias BlockScoutWeb.Plug.{CheckAccountAPI, CheckApiV2}

  pipeline :api do
    plug(:accepts, ["json"])
  end

  pipeline :account_api do
    plug(:fetch_session)
    plug(:protect_from_forgery)
    plug(CheckAccountAPI)
  end

  pipeline :api_v2 do
    plug(CheckApiV2)
    plug(:fetch_session)
    plug(:protect_from_forgery)
  end

  alias BlockScoutWeb.Account.Api.V1.{TagsController, UserController}

  scope "/account/v1", as: :account_v1 do
    pipe_through(:api)
    pipe_through(:account_api)

    get("/get_csrf", UserController, :get_csrf)

    scope "/user" do
      get("/info", UserController, :info)

      get("/watchlist", UserController, :watchlist)
      delete("/watchlist/:id", UserController, :delete_watchlist)
      post("/watchlist", UserController, :create_watchlist)
      put("/watchlist/:id", UserController, :update_watchlist)

      get("/api_keys", UserController, :api_keys)
      delete("/api_keys/:api_key", UserController, :delete_api_key)
      post("/api_keys", UserController, :create_api_key)
      put("/api_keys/:api_key", UserController, :update_api_key)

      get("/custom_abis", UserController, :custom_abis)
      delete("/custom_abis/:id", UserController, :delete_custom_abi)
      post("/custom_abis", UserController, :create_custom_abi)
      put("/custom_abis/:id", UserController, :update_custom_abi)

      get("/public_tags", UserController, :public_tags_requests)
      delete("/public_tags/:id", UserController, :delete_public_tags_request)
      post("/public_tags", UserController, :create_public_tags_request)
      put("/public_tags/:id", UserController, :update_public_tags_request)

      scope "/tags" do
        get("/address/", UserController, :tags_address)
        get("/address/:id", UserController, :tags_address)
        delete("/address/:id", UserController, :delete_tag_address)
        post("/address/", UserController, :create_tag_address)
        put("/address/:id", UserController, :update_tag_address)

        get("/transaction/", UserController, :tags_transaction)
        get("/transaction/:id", UserController, :tags_transaction)
        delete("/transaction/:id", UserController, :delete_tag_transaction)
        post("/transaction/", UserController, :create_tag_transaction)
        put("/transaction/:id", UserController, :update_tag_transaction)
      end
    end
  end

  scope "/account/v1" do
    pipe_through(:api)
    pipe_through(:account_api)

    scope "/tags" do
      get("/address/:address_hash", TagsController, :tags_address)

      get("/transaction/:transaction_hash", TagsController, :tags_transaction)
    end
  end

  @rpc_module_map Application.compile_env(:block_scout_web, :rpc_module_map)

  scope "/v2", as: :api_v2 do
    pipe_through(:api)
    pipe_through(:api_v2)

    alias BlockScoutWeb.API.V2

    get("/search", V2.SearchController, :search)

    scope "/config" do
      get("/json-rpc-url", V2.ConfigController, :json_rpc_url)
    end

    scope "/transactions" do
      get("/", V2.TransactionController, :transactions)
      get("/:transaction_hash", V2.TransactionController, :transaction)
      get("/:transaction_hash/token-transfers", V2.TransactionController, :token_transfers)
      get("/:transaction_hash/internal-transactions", V2.TransactionController, :internal_transactions)
      get("/:transaction_hash/logs", V2.TransactionController, :logs)
      get("/:transaction_hash/raw-trace", V2.TransactionController, :raw_trace)
    end

    scope "/blocks" do
      get("/", V2.BlockController, :blocks)
      get("/:block_hash_or_number", V2.BlockController, :block)
      get("/:block_hash_or_number/transactions", V2.BlockController, :transactions)
    end

    scope "/addresses" do
      get("/:address_hash", V2.AddressController, :address)
      get("/:address_hash/token-balances", V2.AddressController, :token_balances)
      get("/:address_hash/transactions", V2.AddressController, :transactions)
      get("/:address_hash/token-transfers", V2.AddressController, :token_transfers)
      get("/:address_hash/internal-transactions", V2.AddressController, :internal_transactions)
      get("/:address_hash/logs", V2.AddressController, :logs)
      get("/:address_hash/blocks-validated", V2.AddressController, :blocks_validated)
      get("/:address_hash/coin-balance-history", V2.AddressController, :coin_balance_history)
      get("/:address_hash/coin-balance-history-by-day", V2.AddressController, :coin_balance_history_by_day)
    end

    scope "/main-page" do
      get("/blocks", V2.MainPageController, :blocks)
      get("/transactions", V2.MainPageController, :transactions)
    end

    scope "/stats" do
      get("/", V2.StatsController, :stats)

      scope "/charts" do
        get("/transactions", V2.StatsController, :transactions_chart)
        get("/market", V2.StatsController, :market_chart)
      end
    end
  end

  scope "/v1", as: :api_v1 do
    pipe_through(:api)
    alias BlockScoutWeb.API.{EthRPC, RPC.RPCTranslator, V1}
    alias BlockScoutWeb.API.V1.HealthController
    alias BlockScoutWeb.API.V2.SearchController

    # leave the same endpoint in v1 in order to keep backward compatibility
    get("/search", SearchController, :search)
    get("/health", HealthController, :health)
    get("/health/liveness", HealthController, :alive?)
    get("/gas-price-oracle", V1.GasPriceOracleController, :gas_price_oracle)

    if Application.compile_env(:block_scout_web, [__MODULE__, :reading_enabled]) do
      get("/supply", V1.SupplyController, :supply)
      post("/eth-rpc", EthRPC.EthController, :eth_request)
    end

    if Application.compile_env(:block_scout_web, [__MODULE__, :writing_enabled]) do
      post("/decompiled_smart_contract", V1.DecompiledSmartContractController, :create)
      post("/verified_smart_contracts", V1.VerifiedSmartContractController, :create)
    end

    if Application.compile_env(:block_scout_web, [__MODULE__, :reading_enabled]) do
      forward("/", RPCTranslator, @rpc_module_map)
    end
  end

  # For backward compatibility. Should be removed
  scope "/" do
    pipe_through(:api)
    alias BlockScoutWeb.API.EthRPC

    if Application.compile_env(:block_scout_web, [__MODULE__, :reading_enabled]) do
      post("/eth-rpc", EthRPC.EthController, :eth_request)

      forward("/", RPCTranslatorForwarder, @rpc_module_map)
    end
  end
end
