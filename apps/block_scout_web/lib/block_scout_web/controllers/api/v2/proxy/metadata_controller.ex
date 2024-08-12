defmodule BlockScoutWeb.API.V2.Proxy.MetadataServiceController do
  use BlockScoutWeb, :controller

  alias Explorer.MicroserviceInterfaces.Metadata

  action_fallback(BlockScoutWeb.API.V2.FallbackController)

  def addresses(conn, params) do
    with {:ok, addresses} <- Metadata.get_addresses(params) do
      conn
      |> json(params)
    end
  end
end
