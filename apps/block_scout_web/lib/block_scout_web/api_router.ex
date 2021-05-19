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

  pipeline :api do
    plug(:accepts, ["json"])
  end

  scope "/v1", BlockScoutWeb.API.V1, as: :api_v1 do
    pipe_through(:api)
    get("/health", HealthController, :health)

    get("/gas-price-oracle", GasPriceOracleController, :gas_price_oracle)

    if Application.get_env(:block_scout_web, __MODULE__)[:writing_enabled] do
      post("/decompiled_smart_contract", DecompiledSmartContractController, :create)
      post("/verified_smart_contracts", VerifiedSmartContractController, :create)
    end
  end

  if Application.get_env(:block_scout_web, __MODULE__)[:reading_enabled] do
    scope "/" do
      alias BlockScoutWeb.API.{RPC, V1}
      pipe_through(:api)

      scope "/v1", as: :api_v1 do
        get("/supply", V1.SupplyController, :supply)
        post("/eth-rpc", RPC.EthController, :eth_request)
      end

      # For backward compatibility. Should be removed
      post("/eth-rpc", RPC.EthController, :eth_request)
    end
  end

  scope "/" do
    pipe_through(:api)
    alias BlockScoutWeb.API.RPC

    scope "/v1", as: :api_v1 do
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

    # For backward compatibility. Should be removed
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
