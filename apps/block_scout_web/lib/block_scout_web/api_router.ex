defmodule BlockScoutWeb.ApiRouter do
  @moduledoc """
  Router for API
  """
  use BlockScoutWeb, :router

  alias BlockScoutWeb.API.RPC

  pipeline :api do
    plug(:accepts, ["json"])
  end

  scope "/v1", as: :api_v1 do
    pipe_through(:api)

    post("/contract_verifications", BlockScoutWeb.AddressContractVerificationController, :create)

    scope "/", BlockScoutWeb.API.V1 do
      get("/supply", SupplyController, :supply)

      post("/decompiled_smart_contract", DecompiledSmartContractController, :create)
      post("/verified_smart_contracts", VerifiedSmartContractController, :create)

      post("/eth_rpc", EthController, :eth_request)

      forward("/", RPCTranslator, %{
        "block" => RPC.BlockController,
        "account" => RPC.AddressController,
        "logs" => RPC.LogsController,
        "token" => RPC.TokenController,
        "stats" => RPC.StatsController,
        "contract" => RPC.ContractController,
        "transaction" => RPC.TransactionController
      })
    end
  end

  # For backward compatibility. Should be removed
  scope "/", BlockScoutWeb.API.RPC do
    pipe_through(:api)

    post("/eth_rpc", EthController, :eth_request)

    forward("/", RPCTranslator, %{
      "block" => RPC.BlockController,
      "account" => RPC.AddressController,
      "logs" => RPC.LogsController,
      "token" => RPC.TokenController,
      "stats" => RPC.StatsController,
      "contract" => RPC.ContractController,
      "transaction" => RPC.TransactionController
    })
  end
end
