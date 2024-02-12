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

  @token_properties %{
    "circulating_supply" => 0,
    "cmc_rank" => 2977,
    "date_added" => "2021-12-06T11:25:31.000Z",
    "id" => 15658,
    "infinite_supply" => false,
    "is_active" => 1,
    "is_fiat" => 0,
    "last_updated" => "2023-09-12T09:03:00.000Z",
    "max_supply" => 210_240_000,
    "name" => "Qitmeer Network",
    "num_market_pairs" => 10,
    "platform" => nil,
    "quote" => %{
      "USD" => %{
        "fully_diluted_market_cap" => 27_390_222.61,
        "last_updated" => "2023-09-12T09:03:00.000Z",
        "market_cap" => 0,
        "market_cap_dominance" => 0,
        "percent_change_1h" => -0.14807635,
        "percent_change_24h" => -4.05784287,
        "percent_change_30d" => -20.18918329,
        "percent_change_60d" => 85.21384726,
        "percent_change_7d" => -5.49776979,
        "percent_change_90d" => 22.27442093,
        "price" => 0.13028073920022334,
        "tvl" => nil,
        "volume_24h" => 93766.09652096,
        "volume_change_24h" => -0.9423
      }
    },
    "self_reported_circulating_supply" => 71_348_557,
    "self_reported_market_cap" => 9_295_342.74682927,
    "slug" => "qitmeer-network",
    "symbol" => "MEER",
    "tags" => [],
    "total_supply" => 71_348_557,
    "tvl_ratio" => nil
  }

  @market_data_multiple_tokens %{
    "MEER" => [
      @token_properties,
      %{
        "circulating_supply" => nil,
        "cmc_rank" => nil,
        "date_added" => "2023-05-12T15:52:05.000Z",
        "id" => 25240,
        "infinite_supply" => false,
        "is_active" => 0,
        "is_fiat" => 0,
        "last_updated" => "2023-09-12T09:05:15.725Z",
        "max_supply" => 210_240_000,
        "name" => "Meer Coin",
        "num_market_pairs" => nil,
        "platform" => nil,
        "quote" => %{
          "USD" => %{
            "fully_diluted_market_cap" => nil,
            "last_updated" => "2023-09-12T09:05:15.725Z",
            "market_cap" => nil,
            "market_cap_dominance" => nil,
            "percent_change_1h" => nil,
            "percent_change_24h" => nil,
            "percent_change_30d" => nil,
            "percent_change_60d" => nil,
            "percent_change_7d" => nil,
            "percent_change_90d" => nil,
            "price" => 0,
            "tvl" => nil,
            "volume_24h" => nil,
            "volume_change_24h" => nil
          }
        },
        "self_reported_circulating_supply" => nil,
        "self_reported_market_cap" => nil,
        "slug" => "meer-coin",
        "symbol" => "MEER",
        "tags" => [],
        "total_supply" => nil,
        "tvl_ratio" => nil
      }
    ]
  }

  @market_data_single_token %{
    "15658" => @token_properties
  }

  describe "get_token_properties/1" do
    test "returns a single token property, when market_data contains multiple tokens" do
      assert CoinMarketCap.get_token_properties(@market_data_multiple_tokens) == @token_properties
    end

    test "returns a single token property, when market_data contains a single token" do
      assert CoinMarketCap.get_token_properties(@market_data_single_token) == @token_properties
    end
  end
end
