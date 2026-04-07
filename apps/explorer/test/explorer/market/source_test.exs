defmodule Explorer.Market.SourceTest do
  use ExUnit.Case, async: true

  alias Explorer.Market.Source

  describe "zero_or_nil?/1" do
    test "returns true for nil" do
      assert Source.zero_or_nil?(nil)
    end

    test "returns true for Decimal zero" do
      assert Source.zero_or_nil?(Decimal.new(0))
    end

    test "returns true for Decimal zero with different representations" do
      assert Source.zero_or_nil?(Decimal.new("0.0"))
      assert Source.zero_or_nil?(Decimal.new("0.00"))
    end

    test "returns false for positive Decimal" do
      refute Source.zero_or_nil?(Decimal.new("1.5"))
    end

    test "returns false for negative Decimal" do
      refute Source.zero_or_nil?(Decimal.new("-1.5"))
    end
  end

  describe "to_decimal/1" do
    test "returns nil for nil" do
      assert Source.to_decimal(nil) == nil
    end

    test "returns Decimal as-is" do
      decimal = Decimal.new("1.23")
      assert Source.to_decimal(decimal) == decimal
    end

    test "converts float to Decimal" do
      assert Source.to_decimal(3.14) == Decimal.from_float(3.14)
    end

    test "converts integer to Decimal" do
      assert Source.to_decimal(42) == Decimal.new(42)
    end

    test "converts string to Decimal" do
      assert Source.to_decimal("123.45") == Decimal.new("123.45")
    end

    test "converts zero values" do
      assert Source.to_decimal(0) == Decimal.new(0)
      assert Source.to_decimal(0.0) == Decimal.from_float(0.0)
      assert Source.to_decimal("0") == Decimal.new("0")
    end
  end

  describe "maybe_get_date/1" do
    test "returns nil for nil" do
      assert Source.maybe_get_date(nil) == nil
    end

    test "parses valid ISO8601 date" do
      assert Source.maybe_get_date("2025-02-14T05:40:07.774Z") == ~U[2025-02-14 05:40:07.774Z]
    end

    test "returns nil for invalid date string" do
      assert Source.maybe_get_date("not-a-date") == nil
    end

    test "returns nil for empty string" do
      assert Source.maybe_get_date("") == nil
    end
  end

  describe "handle_image_url/1" do
    test "returns nil for nil" do
      assert Source.handle_image_url(nil) == nil
    end

    test "returns valid URL" do
      url = "https://example.com/image.png"
      assert Source.handle_image_url(url) == url
    end

    test "returns nil for invalid URL without host" do
      assert Source.handle_image_url("not-a-url") == nil
    end
  end

  describe "secondary_coin_string/1" do
    test "returns 'Secondary coin' when true" do
      assert Source.secondary_coin_string(true) == "Secondary coin"
    end

    test "returns 'Coin' when false" do
      assert Source.secondary_coin_string(false) == "Coin"
    end
  end

  describe "unexpected_response_error/2" do
    test "formats error message with source and response" do
      result = Source.unexpected_response_error("CoinGecko", %{"error" => "bad request"})
      assert result =~ "CoinGecko"
      assert result =~ "bad request"
    end
  end
end
