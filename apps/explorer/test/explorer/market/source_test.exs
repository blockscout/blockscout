# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Market.SourceTest do
  # Source selection tests below mutate application config, so the module cannot run async.
  use ExUnit.Case, async: false

  alias Explorer.Market.Source
  alias Explorer.Market.Source.{CoinGecko, CoinMarketCap, CryptoCompare}

  describe "native_coin_price_history_source/0" do
    setup :reset_history_sources_config

    test "returns configured source when set" do
      put_source_config(native_coin_history_source: CryptoCompare)
      put_coin_gecko_config(coin_id: "ethereum")

      assert Source.native_coin_price_history_source() == CryptoCompare
    end

    test "prefers CoinGecko over CryptoCompare when CoinGecko coin ID is configured" do
      put_coin_gecko_config(coin_id: "ethereum")
      put_crypto_compare_config(coin_symbol: "ETH")

      assert Source.native_coin_price_history_source() == CoinGecko
    end

    test "falls back to CryptoCompare when CoinGecko coin ID is not configured" do
      put_coin_gecko_config(coin_id: nil)
      put_coin_market_cap_config(coin_id: nil)
      put_crypto_compare_config(coin_symbol: "ETH")

      assert Source.native_coin_price_history_source() == CryptoCompare
    end
  end

  describe "secondary_coin_price_history_source/0" do
    setup :reset_history_sources_config

    test "returns configured source when set" do
      put_source_config(secondary_coin_history_source: CryptoCompare)
      put_coin_gecko_config(secondary_coin_id: "optimism")

      assert Source.secondary_coin_price_history_source() == CryptoCompare
    end

    test "prefers CoinGecko over CryptoCompare when CoinGecko secondary coin ID is configured" do
      put_coin_gecko_config(secondary_coin_id: "optimism")
      put_crypto_compare_config(secondary_coin_symbol: "OP")

      assert Source.secondary_coin_price_history_source() == CoinGecko
    end

    test "falls back to CryptoCompare when CoinGecko secondary coin ID is not configured" do
      put_coin_gecko_config(secondary_coin_id: nil)
      put_coin_market_cap_config(secondary_coin_id: nil)
      put_crypto_compare_config(secondary_coin_symbol: "OP")

      assert Source.secondary_coin_price_history_source() == CryptoCompare
    end
  end

  defp reset_history_sources_config(_context) do
    source_configuration = Application.get_env(:explorer, Source)
    coin_gecko_configuration = Application.get_env(:explorer, CoinGecko)
    coin_market_cap_configuration = Application.get_env(:explorer, CoinMarketCap)
    crypto_compare_configuration = Application.get_env(:explorer, CryptoCompare)

    put_source_config(native_coin_history_source: nil, secondary_coin_history_source: nil)

    on_exit(fn ->
      Application.put_env(:explorer, Source, source_configuration)
      Application.put_env(:explorer, CoinGecko, coin_gecko_configuration)
      Application.put_env(:explorer, CoinMarketCap, coin_market_cap_configuration)
      Application.put_env(:explorer, CryptoCompare, crypto_compare_configuration)
    end)

    :ok
  end

  defp put_source_config(overrides), do: put_config(Source, overrides)
  defp put_coin_gecko_config(overrides), do: put_config(CoinGecko, overrides)
  defp put_coin_market_cap_config(overrides), do: put_config(CoinMarketCap, overrides)
  defp put_crypto_compare_config(overrides), do: put_config(CryptoCompare, overrides)

  defp put_config(module, overrides) do
    initial = Application.get_env(:explorer, module) || []
    Application.put_env(:explorer, module, Keyword.merge(initial, overrides))
  end

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
