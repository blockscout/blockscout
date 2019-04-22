defmodule Explorer.ExchangeRates.Source.CoinGeckoTest do
  use ExUnit.Case

  alias Explorer.ExchangeRates.Token
  alias Explorer.ExchangeRates.Source.CoinGecko
  alias Plug.Conn

  @json_btc_price """
  {
    "rates": {
      "usd": {
        "name": "US Dollar",
        "unit": "$",
        "value": 6547.418,
        "type": "fiat"
      }
    }
  }
  """

  @json_mkt_data """
  [
    {
      "id": "poa-network",
      "symbol": "poa",
      "name": "POA Network",
      "image": "https://assets.coingecko.com/coins/images/3157/large/poa.jpg?1520829019",
      "current_price": 0.114782883773693,
      "market_cap": 25248999.6735956,
      "market_cap_rank": 185,
      "total_volume": 2344442.13578437,
      "high_24h": 0.115215129840519,
      "low_24h": 0.101039753612939,
      "price_change_24h": 0.0135970966607094,
      "price_change_percentage_24h": 13.437753511298,
      "market_cap_change_24h": 3058195.58191147,
      "market_cap_change_percentage_24h": 13.7813644304017,
      "circulating_supply": "219935174.0",
      "total_supply": 252193195,
      "ath": 0.935923393359191,
      "ath_change_percentage": -87.731057963078,
      "ath_date": "2018-05-10T09:45:31.809Z",
      "roi": null,
      "last_updated": "2018-10-23T01:25:31.764Z"
    }
  ]
  """

  describe "format_data/1" do
    setup do
      bypass = Bypass.open()
      Application.put_env(:explorer, CoinGecko, base_url: "http://localhost:#{bypass.port}")

      {:ok, bypass: bypass}
    end

    test "returns valid tokens with valid data", %{bypass: bypass} do
      Bypass.expect(bypass, "GET", "/exchange_rates", fn conn ->
        Conn.resp(conn, 200, @json_btc_price)
      end)

      {:ok, expected_date, 0} = "2018-10-23T01:25:31.764Z" |> DateTime.from_iso8601()

      expected = [
        %Token{
          available_supply: Decimal.new("252193195"),
          total_supply: Decimal.new("252193195"),
          btc_value: Decimal.new("0.00001753101509231471092879666458"),
          id: "poa-network",
          last_updated: expected_date,
          market_cap_usd: Decimal.new("25248999.6735956"),
          name: "POA Network",
          symbol: "poa",
          usd_value: Decimal.new("0.114782883773693"),
          volume_24h_usd: Decimal.new("2344442.13578437")
        }
      ]

      assert expected == CoinGecko.format_data(@json_mkt_data)
    end

    test "returns nothing when given bad data", %{bypass: bypass} do
      Bypass.expect(bypass, "GET", "/exchange_rates", fn conn ->
        Conn.resp(conn, 200, @json_btc_price)
      end)

      bad_data = """
        [{"id": "poa-network"}]
      """

      assert [] = CoinGecko.format_data(bad_data)
    end
  end
end
