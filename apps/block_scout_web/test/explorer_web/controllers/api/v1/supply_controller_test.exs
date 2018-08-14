defmodule BlockScoutWeb.API.V1.SupplyControllerTest do
  use BlockScoutWeb.ConnCase

  alias Explorer.Chain

  test "supply", %{conn: conn} do
    request = get(conn, api_v1_supply_path(conn, :supply))
    assert response = json_response(request, 200)

    assert response["total_supply"] == Chain.total_supply()
    assert response["circulating_supply"] == Chain.circulating_supply()
  end
end
