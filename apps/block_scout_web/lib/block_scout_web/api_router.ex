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

  scope "/v1", as: :api_v1 do
    pipe_through(:api)

    scope "/" do
      alias BlockScoutWeb.API.{RPC, V1}
      get("/supply", V1.SupplyController, :supply)

      post("/eth_rpc", RPC.EthController, :eth_request)

      forward("/", RPC.RPCTranslator, %{
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
  scope "/" do
    alias BlockScoutWeb.API.RPC
    pipe_through(:api)

    post("/eth_rpc", RPC.EthController, :eth_request)

    forward("/", RPCTranslatorForwarder, %{
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
