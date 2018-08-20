defmodule BlockScoutWeb.ChainViewTest do
  use BlockScoutWeb.ConnCase, async: true

  alias Explorer.ExchangeRates.Token
  alias BlockScoutWeb.ChainView

  describe "encode_market_history_data/1" do
    test "returns a JSON encoded market history data" do
      market_history_data = [
        %Explorer.Market.MarketHistory{
          closing_price: Decimal.new("0.078"),
          date: ~D[2018-08-20]
        }
      ]

      assert "[{\"closing_price\":\"0.078\",\"date\":\"2018-08-20\"}]" ==
               ChainView.encode_market_history_data(market_history_data)
    end
  end

  describe "format_exchange_rate/1" do
    test "returns a formatted usd value from a `Token`'s usd_value" do
      token = %Token{usd_value: Decimal.new(5.45)}

      assert "$5.45 USD" == ChainView.format_exchange_rate(token)
      assert nil == ChainView.format_exchange_rate(%Token{usd_value: nil})
    end
  end

  describe "format_market_cap/1" do
    test "returns a formatted usd value from a `Token`'s market_cap_usd" do
      token = %Token{market_cap_usd: Decimal.new(5.4)}

      assert "$5.40 USD" == ChainView.format_market_cap(token)
      assert nil == ChainView.format_market_cap(%Token{market_cap_usd: nil})
    end
  end
end
