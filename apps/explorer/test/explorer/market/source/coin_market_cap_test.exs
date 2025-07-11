defmodule Explorer.Market.Source.CoinMarketCapTest do
  use ExUnit.Case

  alias Explorer.Market.Source
  alias Explorer.Market.Source.CoinMarketCap
  alias Plug.Conn

  setup do
    bypass = Bypass.open()

    coin_market_cap_configuration = Application.get_env(:explorer, CoinMarketCap)
    source_configuration = Application.get_env(:explorer, Explorer.Market.Source)

    Application.put_env(:explorer, Explorer.Market.Source,
      native_coin_source: CoinMarketCap,
      secondary_coin_source: CoinMarketCap,
      tokens_source: CoinMarketCap,
      native_coin_history_source: CoinMarketCap,
      secondary_coin_history_source: CoinMarketCap,
      market_cap_history_source: CoinMarketCap,
      tvl_history_source: CoinMarketCap
    )

    Application.put_env(:explorer, CoinMarketCap,
      base_url: "http://localhost:#{bypass.port}",
      coin_id: "123",
      secondary_coin_id: "456",
      currency_id: "2781"
    )

    Application.put_env(:tesla, :adapter, Tesla.Adapter.Mint)

    on_exit(fn ->
      Application.put_env(:explorer, Explorer.Market.Source, source_configuration)
      Application.put_env(:explorer, CoinMarketCap, coin_market_cap_configuration)
      Application.put_env(:tesla, :adapter, Explorer.Mock.TeslaAdapter)
    end)

    {:ok, bypass: bypass}
  end

  describe "fetch_native_coin/0" do
    test "fetches native coin", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/cryptocurrency/quotes/latest", fn conn ->
        assert conn.query_string == "id=123&convert_id=2781&aux=circulating_supply,total_supply"
        Conn.resp(conn, 200, json_cryptocurrency_quotes_latest("123", "2781", "10.1"))
      end)

      assert {:ok,
              %Explorer.Market.Token{
                available_supply: Decimal.new("19824162"),
                total_supply: Decimal.new("19824162"),
                btc_value: nil,
                last_updated: ~U[2025-02-14 14:34:00.000Z],
                market_cap: Decimal.new("1917742660653.5574"),
                tvl: Decimal.new("1123.123"),
                name: "Bitcoin",
                symbol: "BTC",
                fiat_value: Decimal.new("10.1"),
                volume_24h: Decimal.new("28724591782.645985"),
                image_url: nil
              }} == CoinMarketCap.fetch_native_coin()
    end
  end

  describe "fetch_secondary_coin/0" do
    test "fetches secondary coin", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/cryptocurrency/quotes/latest", fn conn ->
        assert conn.query_string == "id=456&convert_id=2781&aux=circulating_supply,total_supply"
        Conn.resp(conn, 200, json_cryptocurrency_quotes_latest("456", "2781", "20.2"))
      end)

      assert {:ok,
              %Explorer.Market.Token{
                available_supply: Decimal.new("19824162"),
                total_supply: Decimal.new("19824162"),
                btc_value: nil,
                last_updated: ~U[2025-02-14 14:34:00.000Z],
                market_cap: Decimal.new("1917742660653.5574"),
                tvl: Decimal.new("1123.123"),
                name: "Bitcoin",
                symbol: "BTC",
                fiat_value: Decimal.new("20.2"),
                volume_24h: Decimal.new("28724591782.645985"),
                image_url: nil
              }} == CoinMarketCap.fetch_secondary_coin()
    end
  end

  describe "fetch_native_coin_price_history/1" do
    test "fetches native coin price history", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/cryptocurrency/quotes/historical", fn conn ->
        assert conn.query_string == "id=123&count=3&interval=daily&convert_id=2781&aux=price"
        Conn.resp(conn, 200, json_cryptocurrency_quotes_historical_price("2781"))
      end)

      assert {:ok,
              [
                %{
                  date: ~D[2025-02-11],
                  opening_price: Decimal.new("1.1"),
                  closing_price: Decimal.new("2.2"),
                  secondary_coin: false
                },
                %{
                  date: ~D[2025-02-12],
                  opening_price: Decimal.new("2.2"),
                  closing_price: Decimal.new("3.3"),
                  secondary_coin: false
                },
                %{
                  date: ~D[2025-02-13],
                  opening_price: Decimal.new("3.3"),
                  closing_price: Decimal.new("3.3"),
                  secondary_coin: false
                }
              ]} == CoinMarketCap.fetch_native_coin_price_history(3)
    end
  end

  describe "fetch_secondary_coin_price_history/1" do
    test "fetches secondary coin price history", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/cryptocurrency/quotes/historical", fn conn ->
        assert conn.query_string == "id=456&count=3&interval=daily&convert_id=2781&aux=price"
        Conn.resp(conn, 200, json_cryptocurrency_quotes_historical_price("2781"))
      end)

      assert {:ok,
              [
                %{
                  date: ~D[2025-02-11],
                  opening_price: Decimal.new("1.1"),
                  closing_price: Decimal.new("2.2"),
                  secondary_coin: true
                },
                %{
                  date: ~D[2025-02-12],
                  opening_price: Decimal.new("2.2"),
                  closing_price: Decimal.new("3.3"),
                  secondary_coin: true
                },
                %{
                  date: ~D[2025-02-13],
                  opening_price: Decimal.new("3.3"),
                  closing_price: Decimal.new("3.3"),
                  secondary_coin: true
                }
              ]} == CoinMarketCap.fetch_secondary_coin_price_history(3)
    end
  end

  describe "fetch_market_cap_history/1" do
    test "fetches market cap history", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/cryptocurrency/quotes/historical", fn conn ->
        assert conn.query_string == "id=123&count=3&interval=daily&convert_id=2781&aux=market_cap"
        Conn.resp(conn, 200, json_cryptocurrency_quotes_historical_market_cap("2781"))
      end)

      assert {:ok,
              [
                %{
                  date: ~D[2025-02-11],
                  market_cap: Decimal.new("1.1")
                },
                %{
                  date: ~D[2025-02-12],
                  market_cap: Decimal.new("2.2")
                },
                %{
                  date: ~D[2025-02-13],
                  market_cap: Decimal.new("3.3")
                }
              ]} == CoinMarketCap.fetch_market_cap_history(3)
    end
  end

  defp json_cryptocurrency_quotes_latest(coin_id, quote_, price) do
    """
    {
      "status": {
          "timestamp": "2025-02-14T14:36:19.381Z",
          "error_code": 0,
          "error_message": null,
          "elapsed": 40,
          "credit_count": 1,
          "notice": null
      },
      "data": {
          "#{coin_id}": {
              "id": "#{coin_id}",
              "name": "Bitcoin",
              "symbol": "BTC",
              "slug": "bitcoin",
              "circulating_supply": 19824162,
              "total_supply": 19824162,
              "infinite_supply": false,
              "self_reported_circulating_supply": null,
              "self_reported_market_cap": null,
              "tvl_ratio": null,
              "last_updated": "2025-02-14T14:34:00.000Z",
              "quote": {
                  "#{quote_}": {
                      "price": #{price},
                      "volume_24h": 28724591782.645985,
                      "volume_change_24h": -36.6471,
                      "percent_change_1h": -0.18680567,
                      "percent_change_24h": 0.87814048,
                      "percent_change_7d": -2.76152837,
                      "percent_change_30d": -2.20875276,
                      "percent_change_60d": -7.43141934,
                      "percent_change_90d": 6.40010375,
                      "market_cap": 1917742660653.5574,
                      "market_cap_dominance": 59.6002,
                      "fully_diluted_market_cap": 2031490454614.16,
                      "tvl": 1123.123,
                      "last_updated": "2025-02-14T14:34:00.000Z"
                  }
              }
          }
      }
    }
    """
  end

  defp json_cryptocurrency_quotes_historical_price(quote_) do
    """
    {
      "status": {
        "timestamp": "2025-02-14T15:25:12.899Z",
        "error_code": 0,
        "error_message": null,
        "elapsed": 24,
        "credit_count": 1,
        "notice": null
      },
      "data": {
        "quotes": [
          {
            "timestamp": "2025-02-11T00:00:00.000Z",
            "quote": {
              "#{quote_}": {
                "percent_change_1h": 0.027528276011,
                "percent_change_24h": 5.984576760753,
                "percent_change_7d": -1.059038246456,
                "percent_change_30d": -20.606205609488,
                "price": 1.1
              }
            }
          },
          {
            "timestamp": "2025-02-12T00:00:00.000Z",
            "quote": {
              "#{quote_}": {
                "percent_change_1h": -0.400785518608,
                "percent_change_24h": -2.314299841771,
                "percent_change_7d": 1.485637309274,
                "percent_change_30d": -20.770258984011,
                "price": 2.2
              }
            }
          },
          {
            "timestamp": "2025-02-13T00:00:00.000Z",
            "quote": {
              "#{quote_}": {
                "percent_change_1h": 0.245180938342,
                "percent_change_24h": 5.905610772005,
                "percent_change_7d": 10.144915884842,
                "percent_change_30d": -13.587075187197,
                "price": 3.3
              }
            }
          }
        ],
        "id": 1765,
        "name": "EOS",
        "symbol": "EOS"
      }
    }
    """
  end

  defp json_cryptocurrency_quotes_historical_market_cap(quote_) do
    """
    {
      "status": {
        "timestamp": "2025-02-14T15:50:40.656Z",
        "error_code": 0,
        "error_message": null,
        "elapsed": 12,
        "credit_count": 1,
        "notice": null
      },
      "data": {
        "quotes": [
          {
            "timestamp": "2025-02-11T00:00:00.000Z",
            "quote": { "2781": { "market_cap": 1.1 } }
          },
          {
            "timestamp": "2025-02-12T00:00:00.000Z",
            "quote": { "2781": { "market_cap": 2.2 } }
          },
          {
            "timestamp": "2025-02-13T00:00:00.000Z",
            "quote": { "2781": { "market_cap": 3.3 } }
          }
        ],
        "id": 1765,
        "name": "EOS",
        "symbol": "EOS"
      }
    }
    """
  end
end
