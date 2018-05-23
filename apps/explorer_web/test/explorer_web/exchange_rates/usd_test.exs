defmodule ExplorerWeb.ExchangeRates.USDTest do
  use ExUnit.Case, async: true

  alias ExplorerWeb.ExchangeRates.USD
  alias Explorer.ExchangeRates.Token
  alias Explorer.Chain.Wei

  describe "from/2" do
    test "with nil wei returns null object" do
      token = %Token{usd_value: Decimal.new(0.5)}

      assert USD.null() == USD.from(nil, token)
    end

    test "with nil token returns nil" do
      wei = %Wei{value: Decimal.new(10_000_000_000_000)}

      assert USD.null() == USD.from(wei, nil)
    end

    test "without a wei value returns nil" do
      wei = %Wei{value: nil}
      token = %Token{usd_value: Decimal.new(0.5)}

      assert USD.null() == USD.from(wei, token)
    end

    test "without an exchange rate returns nil" do
      wei = %Wei{value: Decimal.new(10_000_000_000_000)}
      token = %Token{usd_value: nil}

      assert USD.null() == USD.from(wei, token)
    end

    test "returns formatted usd value" do
      wei = %Wei{value: Decimal.new(10_000_000_000_000)}
      token = %Token{usd_value: Decimal.new(0.5)}

      assert %USD{value: Decimal.new(0.000005)} == USD.from(wei, token)
    end

    test "returns USD struct from decimal usd value" do
      value = Decimal.new(0.000005)

      assert %USD{value: ^value} = USD.from(value)
    end
  end
end
