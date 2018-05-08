defmodule Explorer.ExchangeRates.Source.CoinMarketCapTest do
  use ExUnit.Case

  alias Explorer.ExchangeRates.Token
  alias Explorer.ExchangeRates.Source.CoinMarketCap
  alias Plug.Conn

  @json """
  [
    {
      "id": "poa-network",
      "name": "POA Network",
      "symbol": "POA",
      "rank": "103",
      "price_usd": "0.485053",
      "price_btc": "0.00007032",
      "24h_volume_usd": "20185000.0",
      "market_cap_usd": "98941986.0",
      "available_supply": "203981804.0",
      "total_supply": "254473964.0",
      "max_supply": null,
      "percent_change_1h": "-0.66",
      "percent_change_24h": "12.34",
      "percent_change_7d": "49.15",
      "last_updated": "1523473200"
    }
  ]
  """

  describe "fetch_exchange_rates" do
    setup do
      bypass = Bypass.open()
      Application.put_env(:explorer, CoinMarketCap, base_url: "http://localhost:#{bypass.port}")
      {:ok, bypass: bypass}
    end

    test "with successful request", %{bypass: bypass} do
      Bypass.expect(bypass, fn conn -> Conn.resp(conn, 200, @json) end)

      expected_date = ~N[2018-04-11 19:00:00] |> DateTime.from_naive!("Etc/UTC")

      expected = [
        %Token{
          available_supply: Decimal.new("203981804.0"),
          btc_value: Decimal.new("0.00007032"),
          id: "poa-network",
          last_updated: expected_date,
          market_cap_usd: Decimal.new("98941986.0"),
          name: "POA Network",
          symbol: "POA",
          usd_value: Decimal.new("0.485053"),
          volume_24h_usd: Decimal.new("20185000.0")
        }
      ]

      assert {:ok, ^expected} = CoinMarketCap.fetch_exchange_rates()
    end

    test "with bad request response", %{bypass: bypass} do
      error_text = ~S({"error": "bad request"})
      Bypass.expect(bypass, fn conn -> Conn.resp(conn, 400, error_text) end)
      assert {:error, "bad request"} == CoinMarketCap.fetch_exchange_rates()
    end
  end

  test "format_data/1" do
    expected_date = ~N[2018-04-11 19:00:00] |> DateTime.from_naive!("Etc/UTC")

    expected = [
      %Token{
        available_supply: Decimal.new("203981804.0"),
        btc_value: Decimal.new("0.00007032"),
        id: "poa-network",
        last_updated: expected_date,
        market_cap_usd: Decimal.new("98941986.0"),
        name: "POA Network",
        symbol: "POA",
        usd_value: Decimal.new("0.485053"),
        volume_24h_usd: Decimal.new("20185000.0")
      }
    ]

    assert expected == CoinMarketCap.format_data(@json)
  end
end
