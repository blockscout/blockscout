defmodule BlockScoutWeb.ChainViewTest do
  use BlockScoutWeb.ConnCase, async: true

  alias Explorer.ExchangeRates.Token
  alias BlockScoutWeb.ChainView

  describe "format_exchange_rate/1" do
    test "returns a formatted usd value from a `Token`'s usd_value" do
      token = %Token{usd_value: Decimal.new(5.45)}

      assert "$5.45 USD" == ChainView.format_exchange_rate(token)
      assert nil == ChainView.format_exchange_rate(%Token{usd_value: nil})
    end
  end

  describe "format_volume_24h/1" do
    test "returns a formatted usd value from a `Token`'s volume_24h_usd" do
      token = %Token{volume_24h_usd: Decimal.new(5.456)}

      assert "$5.456 USD" == ChainView.format_volume_24h(token)
      assert nil == ChainView.format_volume_24h(%Token{volume_24h_usd: nil})
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
