defmodule Explorer.ExchangeRates.Source.CoinMarketCapTest do
  use ExUnit.Case

  import Mock

  alias Explorer.ExchangeRates.Rate
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

  describe "fetch_exchange_rate" do
    test "with successful request" do
      with_mock HTTPoison,
        get: fn "https://api.coinmarketcap.com/v1/ticker/poa-network/", _ ->
          {:ok, %HTTPoison.Response{body: @json, status_code: 200}}
        end do
        expected_date = ~N[2018-04-11 19:00:00] |> DateTime.from_naive!("Etc/UTC")

        expected = %Rate{
          last_updated: expected_date,
          ticker_name: "POA Network",
          ticker_symbol: "POA",
          ticker: "poa-network",
          usd_value: "0.485053"
        }

        assert {:ok, ^expected} = CoinMarketCap.fetch_exchange_rate("poa-network")
      end
    end

    test "with errored request" do
      with_mock HTTPoison,
        get: fn "https://api.coinmarketcap.com/v1/ticker/poa-network/", _ ->
          {:error, %HTTPoison.Error{reason: "not found"}}
        end do
        assert {:error, "not found"} == CoinMarketCap.fetch_exchange_rate("poa-network")
      end
    end
  end

  test "format_data/1" do
    expected_date = ~N[2018-04-11 19:00:00] |> DateTime.from_naive!("Etc/UTC")

    expected = %Rate{
      last_updated: expected_date,
      ticker_name: "POA Network",
      ticker_symbol: "POA",
      ticker: "poa-network",
      usd_value: "0.485053"
    }

    assert expected == CoinMarketCap.format_data(@json)
  end
end
