defmodule BlockScoutWeb.API.V2.StatsControllerTest do
  use BlockScoutWeb.ConnCase

  alias Explorer.Counters.{AddressesCounter, AverageBlockTime}

  describe "/stats" do
    setup do
      start_supervised!(AddressesCounter)
      start_supervised!(AverageBlockTime)

      Application.put_env(:explorer, AverageBlockTime, enabled: true, cache_period: 1_800_000)

      on_exit(fn ->
        Application.put_env(:explorer, AverageBlockTime, enabled: false, cache_period: 1_800_000)
      end)

      :ok
    end

    test "get all fields", %{conn: conn} do
      request = get(conn, "/api/v2/stats")
      assert response = json_response(request, 200)

      assert Map.has_key?(response, "total_blocks")
      assert Map.has_key?(response, "total_addresses")
      assert Map.has_key?(response, "total_transactions")
      assert Map.has_key?(response, "average_block_time")
      assert Map.has_key?(response, "coin_price")
      assert Map.has_key?(response, "total_gas_used")
      assert Map.has_key?(response, "transactions_today")
      assert Map.has_key?(response, "gas_used_today")
      assert Map.has_key?(response, "gas_prices")
      assert Map.has_key?(response, "static_gas_price")
      assert Map.has_key?(response, "market_cap")
      assert Map.has_key?(response, "network_utilization_percentage")
    end
  end

  describe "/stats/charts/market" do
    test "get empty data", %{conn: conn} do
      request = get(conn, "/api/v2/stats/charts/market")
      assert response = json_response(request, 200)

      assert response["chart_data"] == []
    end
  end

  describe "/stats/charts/transactions" do
    test "get empty data", %{conn: conn} do
      request = get(conn, "/api/v2/stats/charts/transactions")
      assert response = json_response(request, 200)

      assert response["chart_data"] == []
    end
  end
end
