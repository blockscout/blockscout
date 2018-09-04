defmodule BlockScoutWeb.ChainViewTest do
  use BlockScoutWeb.ConnCase, async: true

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
end
