defmodule BlockScoutWeb.API.V2.TokenViewTest do
  use BlockScoutWeb.ConnCase, async: true

  alias BlockScoutWeb.API.V2.TokenView

  describe "exchange_rate/1" do
    test "returns string when fiat_value exists" do
      assert TokenView.exchange_rate(%{fiat_value: Decimal.new("1.5")}) == "1.5"
    end

    test "returns nil when fiat_value is nil" do
      assert TokenView.exchange_rate(%{fiat_value: nil}) == nil
    end
  end

  describe "render token.json" do
    test "renders token fields" do
      token = insert(:token)
      result = TokenView.render("token.json", %{token: token})

      assert result["symbol"] == token.symbol
      assert result["name"] == token.name
      assert result["type"] == token.type
      assert result["decimals"] == token.decimals
      assert Map.has_key?(result, "address_hash")
      assert Map.has_key?(result, "holders_count")
    end

    test "returns nil for nil token" do
      assert TokenView.render("token.json", %{token: nil}) == nil
    end
  end
end
