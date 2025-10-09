defmodule Explorer.Market.Source.CryptoCompareTest do
  use ExUnit.Case, async: false

  alias Explorer.Market.Source.CryptoCompare
  alias Plug.Conn

  setup do
    bypass = Bypass.open()

    coin = Application.get_env(:explorer, :coin)
    source_configuration = Application.get_env(:explorer, Explorer.Market.Source)
    crypto_compare_configuration = Application.get_env(:explorer, CryptoCompare)

    Application.put_env(:explorer, :coin, "TEST")

    Application.put_env(:explorer, Explorer.Market.Source,
      native_coin_source: CryptoCompare,
      secondary_coin_source: CryptoCompare,
      tokens_source: CryptoCompare,
      native_coin_history_source: CryptoCompare,
      secondary_coin_history_source: CryptoCompare,
      market_cap_history_source: CryptoCompare,
      tvl_history_source: CryptoCompare
    )

    Application.put_env(:explorer, CryptoCompare,
      base_url: "http://localhost:#{bypass.port}",
      coin_symbol: "TEST",
      secondary_coin_symbol: "SECONDARY_TEST",
      currency: "AED"
    )

    Application.put_env(:tesla, :adapter, Tesla.Adapter.Mint)

    on_exit(fn ->
      Application.put_env(:explorer, :coin, coin)
      Application.put_env(:explorer, Explorer.Market.Source, source_configuration)
      Application.put_env(:explorer, CryptoCompare, crypto_compare_configuration)
      Application.put_env(:tesla, :adapter, Explorer.Mock.TeslaAdapter)
    end)

    {:ok, bypass: bypass}
  end

  describe "fetch_native_coin_price_history/1" do
    test "fetches native coin price history", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "data/v2/histoday", fn conn ->
        assert conn.query_string ==
                 "fsym=TEST&limit=3&tsym=AED&extraParams=Blockscout/#{Application.spec(:explorer)[:vsn]}"

        Conn.resp(conn, 200, json_data_v2_histoday())
      end)

      assert {:ok,
              [
                %{
                  date: ~D[2025-02-12],
                  opening_price: Decimal.new("1.1"),
                  closing_price: Decimal.new("2.2"),
                  secondary_coin: false
                },
                %{
                  date: ~D[2025-02-13],
                  opening_price: Decimal.new("2.2"),
                  closing_price: Decimal.new("3.3"),
                  secondary_coin: false
                },
                %{
                  date: ~D[2025-02-14],
                  opening_price: Decimal.new("3.3"),
                  closing_price: Decimal.new("4.4"),
                  secondary_coin: false
                }
              ]} == CryptoCompare.fetch_native_coin_price_history(3)
    end
  end

  describe "fetch_secondary_coin_price_history/1" do
    test "fetches secondary coin price history", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "data/v2/histoday", fn conn ->
        assert conn.query_string ==
                 "fsym=SECONDARY_TEST&limit=3&tsym=AED&extraParams=Blockscout/#{Application.spec(:explorer)[:vsn]}"

        Conn.resp(conn, 200, json_data_v2_histoday())
      end)

      assert {:ok,
              [
                %{
                  date: ~D[2025-02-12],
                  opening_price: Decimal.new("1.1"),
                  closing_price: Decimal.new("2.2"),
                  secondary_coin: true
                },
                %{
                  date: ~D[2025-02-13],
                  opening_price: Decimal.new("2.2"),
                  closing_price: Decimal.new("3.3"),
                  secondary_coin: true
                },
                %{
                  date: ~D[2025-02-14],
                  opening_price: Decimal.new("3.3"),
                  closing_price: Decimal.new("4.4"),
                  secondary_coin: true
                }
              ]} == CryptoCompare.fetch_secondary_coin_price_history(3)
    end
  end

  defp json_data_v2_histoday do
    """
    {
      "Response": "Success",
      "Message": "",
      "HasWarning": false,
      "Type": 100,
      "RateLimit": {},
      "Data": {
        "Aggregated": false,
        "TimeFrom": 1739318400,
        "TimeTo": 1739491200,
        "Data": [
          {
            "time": 1739318400,
            "high": 10229.02,
            "low": 9666.32,
            "open": 1.1,
            "volumefrom": 91397.18,
            "volumeto": 916559418.68,
            "close": 2.2,
            "conversionType": "multiply",
            "conversionSymbol": "BTC"
          },
          {
            "time": 1739404800,
            "high": 9923.31,
            "low": 9641.59,
            "open": 2.2,
            "volumefrom": 60015.86,
            "volumeto": 585622722.7,
            "close": 3.3,
            "conversionType": "multiply",
            "conversionSymbol": "BTC"
          },
          {
            "time": 1739491200,
            "high": 10089.99,
            "low": 9719.38,
            "open": 3.3,
            "volumefrom": 31936.17,
            "volumeto": 319960020.92,
            "close": 4.4,
            "conversionType": "multiply",
            "conversionSymbol": "BTC"
          }
        ]
      }
    }
    """
  end
end
