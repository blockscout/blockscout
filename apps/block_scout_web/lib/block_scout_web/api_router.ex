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
  alias BlockScoutWeb.Plug.CheckAuth

  pipeline :api do
    plug(:accepts, ["json"])
  end

  pipeline :account_api do
    plug(Guardian.Plug.VerifyHeader, module: BlockScoutWeb.Guardian, error_handler: BlockScoutWeb.GuardianErrorHandler)
    plug(CheckAuth)
  end

  scope "/account/v1" do
    alias BlockScoutWeb.Account.Api.V1

    pipe_through(:api)
    pipe_through(:account_api)

    scope "/user" do
      get("/info", V1.UserController, :info)

      get("/watchlist", V1.UserController, :watchlist)
      delete("/watchlist/:id", V1.UserController, :delete_watchlist)
      post("/watchlist", V1.UserController, :create_watchlist)
      put("/watchlist/:id", V1.UserController, :update_watchlist)

      get("/api_keys", V1.UserController, :api_keys)
      delete("/api_keys/:api_key", V1.UserController, :delete_api_key)
      post("/api_keys", V1.UserController, :create_api_key)
      put("/api_keys/:api_key", V1.UserController, :update_api_key)

      get("/custom_abis", V1.UserController, :custom_abis)
      delete("/custom_abis/:id", V1.UserController, :delete_custom_abi)
      post("/custom_abis", V1.UserController, :create_custom_abi)
      put("/custom_abis/:id", V1.UserController, :update_custom_abi)

      scope "/tags" do
        get("/address/", V1.UserController, :tags_address)
        get("/address/:tag_id", V1.UserController, :tags_address)
        delete("/address/:tag_id", V1.UserController, :delete_tag_address)
        post("/address/", V1.UserController, :create_tag_address)

        get("/transaction/", V1.UserController, :tags_transaction)
        get("/transaction/:tag_id", V1.UserController, :tags_transaction)
        delete("/transaction/:tag_id", V1.UserController, :delete_tag_transaction)
        post("/transaction/", V1.UserController, :create_tag_transaction)
      end
    end
  end

  scope "/v1", as: :api_v1 do
    pipe_through(:api)
    alias BlockScoutWeb.API.{EthRPC, RPC, V1}
    alias BlockScoutWeb.API.V1.HealthController

    get("/health", HealthController, :health)
    get("/gas-price-oracle", V1.GasPriceOracleController, :gas_price_oracle)

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
