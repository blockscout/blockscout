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
  alias BlockScoutWeb.Plug.CheckAccountAPI

  pipeline :api do
    plug(:accepts, ["json"])
  end

  pipeline :account_api do
    plug(:fetch_session)
    plug(:protect_from_forgery)
    plug(CheckAccountAPI)
  end

  alias BlockScoutWeb.Account.Api.V1.{TagsController, UserController}

  scope "/account/v1" do
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

  scope "/v1", as: :api_v1 do
    pipe_through(:api)
    alias BlockScoutWeb.API.{EthRPC, RPC, V1}
    alias BlockScoutWeb.API.V1.{GasPriceOracleController, HealthController}

    get("/health", HealthController, :health)
    get("/gas-price-oracle", GasPriceOracleController, :gas_price_oracle)

    if Application.get_env(:block_scout_web, __MODULE__)[:reading_enabled] do
      get("/supply", V1.SupplyController, :supply)
      post("/eth-rpc", EthRPC.EthController, :eth_request)
    end

    if Application.get_env(:block_scout_web, __MODULE__)[:writing_enabled] do
      post("/decompiled_smart_contract", V1.DecompiledSmartContractController, :create)
      post("/verified_smart_contracts", V1.VerifiedSmartContractController, :create)
    end

    if Application.get_env(:block_scout_web, __MODULE__)[:reading_enabled] do
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

  # For backward compatibility. Should be removed
  scope "/" do
    pipe_through(:api)
    alias BlockScoutWeb.API.{EthRPC, RPC}

    if Application.get_env(:block_scout_web, __MODULE__)[:reading_enabled] do
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
