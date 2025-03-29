defmodule BlockScoutWeb.API.V2.Proxy.UniversalProxyController do
  use BlockScoutWeb, :controller

  alias Explorer.ThirdPartyIntegrations.UniversalProxy

  def index(conn, %{"platform" => _platform} = params) do
    {response, status} = UniversalProxy.api_request(params)

    conn
    |> put_status(status)
    |> json(response)
  end
end
