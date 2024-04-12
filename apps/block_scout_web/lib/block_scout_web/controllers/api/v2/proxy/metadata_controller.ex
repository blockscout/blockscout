defmodule BlockScoutWeb.API.V2.Proxy.MetadataController do
  use BlockScoutWeb, :controller

  alias BlockScoutWeb.API.V2.Helper
  alias Explorer.Chain
  alias Explorer.MicroserviceInterfaces.AccountAbstraction

  action_fallback(BlockScoutWeb.API.V2.FallbackController)

  def addresses_by_tag(conn, %{"tag" => tag}) do

  end
end
