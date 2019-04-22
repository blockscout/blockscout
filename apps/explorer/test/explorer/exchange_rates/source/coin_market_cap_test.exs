defmodule Explorer.ExchangeRates.Source.CoinMarketCapTest do
  use ExUnit.Case

  alias Explorer.ExchangeRates.Token
  alias Explorer.ExchangeRates.Source.CoinMarketCap

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

  describe "format_data/1" do
    test "returns valid tokens with valid data" do
      expected_date = ~N[2018-04-11 19:00:00] |> DateTime.from_naive!("Etc/UTC")

      expected = [
        %Token{
          available_supply: Decimal.new("203981804.0"),
          total_supply: Decimal.new("254473964.0"),
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

    test "returns nothing when given bad data" do
      bad_data = """
        [{"id": "poa-network"}]
      """

      assert [] = CoinMarketCap.format_data(bad_data)
    end
  end
end
