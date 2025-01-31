defmodule BlockScoutWeb.API.V2.Proxy.ZerionController do
  use BlockScoutWeb, :controller

  alias BlockScoutWeb.API.RPC.ContractController

  alias Explorer.ThirdPartyIntegrations.Zerion

  action_fallback(BlockScoutWeb.API.V2.FallbackController)

  @doc """
    Function to handle GET requests to `/api/v2/proxy/zerion/wallet-portfolio/:address_hash_param` endpoint.
  """
  @spec wallet_portfolio(Plug.Conn.t(), map()) :: Plug.Conn.t() | {atom(), any()}
  def wallet_portfolio(conn, %{"address_hash_param" => address_hash_string} = params) do
    with {:ok, _address_hash, _address} <- ContractController.validate_address(address_hash_string, params),
         url = Zerion.wallet_portfolio_url(address_hash_string),
         {response, status} <- Zerion.api_request(url, conn),
         {:is_empty_response, false} <- {:is_empty_response, is_nil(response)} do
      conn
      |> put_status(status)
      |> json(response)
    end
  end
end
