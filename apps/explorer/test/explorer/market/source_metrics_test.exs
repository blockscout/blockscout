# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Market.SourceMetricsTest do
  use ExUnit.Case

  use Prometheus.Metric

  alias Explorer.Market.Source
  alias Explorer.Market.Source.CoinGecko
  alias Plug.Conn

  setup do
    bypass = Bypass.open()

    initial_tesla_adapter = Application.fetch_env(:tesla, :adapter)

    Application.put_env(:tesla, :adapter, Tesla.Adapter.Mint)

    on_exit(fn ->
      case initial_tesla_adapter do
        {:ok, adapter} -> Application.put_env(:tesla, :adapter, adapter)
        :error -> Application.delete_env(:tesla, :adapter)
      end
    end)

    {:ok, bypass: bypass}
  end

  describe "market_source_requests_count metric" do
    test "counts a successful request with the source and endpoint labels", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/test", fn conn ->
        Conn.resp(conn, 200, ~s({"result": "ok"}))
      end)

      labels = ["coin_gecko", :test_endpoint, "ok"]
      value_before = counter_value(labels)

      assert {:ok, %{"result" => "ok"}} =
               Source.http_request("http://localhost:#{bypass.port}/test", [], CoinGecko, :test_endpoint)

      assert counter_value(labels) == value_before + 1
    end

    test "counts requests to the same endpoint with different variable parts in one series", %{bypass: bypass} do
      Bypass.expect(bypass, "GET", "/test/0x1", fn conn -> Conn.resp(conn, 200, ~s({})) end)
      Bypass.expect(bypass, "GET", "/test/0x2", fn conn -> Conn.resp(conn, 200, ~s({})) end)

      labels = ["dia", :test_shared_endpoint, "ok"]
      value_before = counter_value(labels)

      Enum.each(["0x1", "0x2"], fn address_hash ->
        assert {:ok, _} =
                 Source.http_request(
                   "http://localhost:#{bypass.port}/test/#{address_hash}",
                   [],
                   Source.DIA,
                   :test_shared_endpoint
                 )
      end)

      assert counter_value(labels) == value_before + 2
    end

    test "counts an error response with the status code as the status label", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/test", fn conn ->
        Conn.resp(conn, 429, "Too many requests")
      end)

      labels = ["coin_gecko", :test_endpoint, "429"]
      value_before = counter_value(labels)

      assert {:error, "429: Too many requests"} =
               Source.http_request("http://localhost:#{bypass.port}/test", [], CoinGecko, :test_endpoint)

      assert counter_value(labels) == value_before + 1
    end

    test "counts a transport error", %{bypass: bypass} do
      Bypass.down(bypass)

      labels = ["coin_gecko", :test_endpoint, "transport_error"]
      value_before = counter_value(labels)

      assert {:error, _reason} =
               Source.http_request("http://localhost:#{bypass.port}/test", [], CoinGecko, :test_endpoint)

      assert counter_value(labels) == value_before + 1
    end
  end

  defp counter_value(labels) do
    case Counter.value(name: :market_source_requests_count, labels: labels) do
      :undefined -> 0
      value -> value
    end
  end
end
