defmodule ExplorerWeb.CurrencyHelpersTest do
  use ExUnit.Case

  alias ExplorerWeb.CurrencyHelpers
  alias ExplorerWeb.ExchangeRates.USD

  doctest ExplorerWeb.CurrencyHelpers, import: true

  test "with nil it returns nil" do
    assert nil == CurrencyHelpers.format_usd_value(nil)
  end

  test "with USD.null() it returns nil" do
    assert nil == CurrencyHelpers.format_usd_value(USD.null())
  end

  describe "format_according_to_decimals/1" do
    test "formats the amount as value considering the given decimals" do
      amount = Decimal.new(205_000_000_000_000)
      decimals = 12

      assert CurrencyHelpers.format_according_to_decimals(amount, decimals) == "205"
    end

    test "considers the decimal places according to the given decimals" do
      amount = Decimal.new(205_000)
      decimals = 12

      assert CurrencyHelpers.format_according_to_decimals(amount, decimals) == "0.000000205"
    end

    test "does not consider right zeros in decimal places" do
      amount = Decimal.new(90_000_000)
      decimals = 6

      assert CurrencyHelpers.format_according_to_decimals(amount, decimals) == "90"
    end

    test "returns the full number when there is no right zeros in decimal places" do
      amount = Decimal.new(9_324_876)
      decimals = 6

      assert CurrencyHelpers.format_according_to_decimals(amount, decimals) == "9.324876"
    end
  end
end
