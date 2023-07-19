defmodule Explorer.ExchangeRates.Source.CoinMarketCapTest do
  use ExUnit.Case

  alias Explorer.ExchangeRates.Source.CoinMarketCap

  describe "source_url/0" do
    test "returns default cmc source url" do
      assert "https://pro-api.coinmarketcap.com/v2/cryptocurrency/quotes/latest?symbol=ETH&CMC_PRO_API_KEY=" ==
               CoinMarketCap.source_url()
    end

    test "returns cmc source url with not default symbol" do
      Application.put_env(:explorer, :coin, "ETC")

      assert "https://pro-api.coinmarketcap.com/v2/cryptocurrency/quotes/latest?symbol=ETC&CMC_PRO_API_KEY=" ==
               CoinMarketCap.source_url()

      Application.put_env(:explorer, :coin, "ETH")
    end

    test "returns cmc source url with id" do
      Application.put_env(:explorer, CoinMarketCap, coin_id: 100_500)

      assert "https://pro-api.coinmarketcap.com/v2/cryptocurrency/quotes/latest?id=100500&CMC_PRO_API_KEY=" ==
               CoinMarketCap.source_url()

      Application.put_env(:explorer, CoinMarketCap, coin_id: nil)
    end
  end

  describe "source_url/1" do
    test "returns cmc source url for symbol" do
      assert "https://pro-api.coinmarketcap.com/v2/cryptocurrency/quotes/latest?symbol=ETH&CMC_PRO_API_KEY=" ==
               CoinMarketCap.source_url("ETH")
    end
  end
end
