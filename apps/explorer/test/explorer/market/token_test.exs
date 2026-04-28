defmodule Explorer.Market.TokenTest do
  use ExUnit.Case, async: true

  alias Explorer.Market.Token

  describe "null/0" do
    test "returns a Token struct with all nil fields" do
      token = Token.null()
      assert %Token{} = token
      assert token.available_supply == nil
      assert token.total_supply == nil
      assert token.btc_value == nil
      assert token.last_updated == nil
      assert token.market_cap == nil
      assert token.tvl == nil
      assert token.name == nil
      assert token.symbol == nil
      assert token.fiat_value == nil
      assert token.volume_24h == nil
      assert token.circulating_supply == nil
      assert token.image_url == nil
    end
  end

  describe "null?/1" do
    test "returns true for null token" do
      assert Token.null?(Token.null())
    end

    test "returns false for non-null token" do
      token = %Token{
        available_supply: Decimal.new("100"),
        total_supply: Decimal.new("100"),
        btc_value: Decimal.new("1"),
        last_updated: ~U[2025-01-01 00:00:00Z],
        market_cap: Decimal.new("1000"),
        tvl: nil,
        name: "Test",
        symbol: "TST",
        fiat_value: Decimal.new("10"),
        volume_24h: Decimal.new("500"),
        image_url: "https://example.com/test.png"
      }

      refute Token.null?(token)
    end

    test "returns false for token with single non-nil field" do
      token = %{Token.null() | name: "Test"}
      refute Token.null?(token)
    end
  end
end
