defmodule BlockScoutWeb.ApiRouter do
  @moduledoc """
  Router for API
  """
  use BlockScoutWeb, :router

  alias BlockScoutWeb.API.RPC
  alias BlockScoutWeb.Plug.GraphQL

  pipeline :api do
    plug(:accepts, ["json"])
  end

  scope "/v1", as: :api_v1 do
    pipe_through(:api)

    post("/contract_verifications", BlockScoutWeb.AddressContractVerificationController, :create)

    scope "/", BlockScoutWeb.API.V1 do
      get("/supply", SupplyController, :supply)

      get("/health", HealthController, :health)

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

  # Needs to be 200 to support the schema introspection for graphiql
  @max_complexity 200

  forward("/graphql", Absinthe.Plug,
    schema: BlockScoutWeb.Schema,
    analyze_complexity: true,
    max_complexity: @max_complexity
  )

  forward("/graphiql", Absinthe.Plug.GraphiQL,
    schema: BlockScoutWeb.Schema,
    interface: :advanced,
    default_query: GraphQL.default_query(),
    socket: BlockScoutWeb.UserSocket,
    analyze_complexity: true,
    max_complexity: @max_complexity
  )

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
