defmodule BlockScoutWeb.Chain.MarketHistoryChartControllerTest do
  use BlockScoutWeb.ConnCase

  describe "GET show/2" do
    test "returns error when not an ajax request" do
      path = market_history_chart_path(BlockScoutWeb.Endpoint, :show)

      conn = get(build_conn(), path)

      assert conn.status == 422
    end

    test "returns ok when request is ajax" do
      path = market_history_chart_path(BlockScoutWeb.Endpoint, :show)

      conn =
        build_conn()
        |> put_req_header("x-requested-with", "xmlhttprequest")
        |> get(path)

      assert json_response(conn, 200)
    end
  end
end
