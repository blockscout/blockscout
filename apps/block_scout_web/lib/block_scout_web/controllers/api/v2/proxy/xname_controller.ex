defmodule BlockScoutWeb.API.V2.Proxy.XnameController do
  use BlockScoutWeb, :controller

  alias BlockScoutWeb.API.RPC.ContractController

  alias Explorer.ThirdPartyIntegrations.Xname

  action_fallback(BlockScoutWeb.API.V2.FallbackController)

  @doc """
    Function to handle GET requests to `/api/v2/proxy/xname/address/:address_hash_param` endpoint.
  """
  @spec address(Plug.Conn.t(), map()) :: Plug.Conn.t() | {atom(), any()}
  def address(conn, %{"address_hash_param" => address_hash_string} = params) do
    with {:ok, _address_hash, _address} <- ContractController.validate_address(address_hash_string, params),
         url = Xname.address_url(address_hash_string),
         {response, status} <- Xname.api_request(url, conn),
         {:is_empty_response, false} <- {:is_empty_response, is_nil(response)} do
      conn
      |> put_status(status)
      |> json(response)
    end
  end
end
