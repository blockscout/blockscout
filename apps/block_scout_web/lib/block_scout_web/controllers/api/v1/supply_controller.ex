defmodule BlockScoutWeb.API.V1.SupplyController do
  use BlockScoutWeb, :controller

  alias BlockScoutWeb.API.APILogger
  alias Explorer.Chain

  def supply(conn, _) do
    APILogger.log(conn)
    total_supply = Chain.total_supply()
    circulating_supply = Chain.circulating_supply()

    render(conn, :supply, total: total_supply, circulating: circulating_supply)
  end
end
