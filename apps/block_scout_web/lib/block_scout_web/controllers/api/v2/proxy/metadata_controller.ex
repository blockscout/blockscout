defmodule BlockScoutWeb.API.V2.Proxy.MetadataController do
  @moduledoc """
  Controller for the metadata service
  """
  use BlockScoutWeb, :controller

  alias Explorer.MicroserviceInterfaces.Metadata

  action_fallback(BlockScoutWeb.API.V2.FallbackController)

  @doc """
  Function to handle GET requests to `/api/v2/proxy/metadata/addresses` endpoint.
  Proxies request to the metadata service. Preloads additional info to the addresses in response.
  If some addresses are not found, they'll be discarded.
  """
  def addresses(conn, params) do
    with {code, body} <- Metadata.get_addresses(params) do
      case code do
        200 ->
          conn
          |> render(:addresses, %{result: body})

        status_code ->
          conn
          |> put_status(status_code)
          |> json(body)
      end
    end
  end
end
