defmodule BlockScoutWeb.API.V1.SupplyController do
  use BlockScoutWeb, :controller

  alias Explorer.Chain

  def supply(conn, _) do
    total_supply = Chain.total_supply()
    circulating_supply = Chain.circulating_supply()

    render(conn, :supply, total: total_supply, circulating: circulating_supply)
  end
end
