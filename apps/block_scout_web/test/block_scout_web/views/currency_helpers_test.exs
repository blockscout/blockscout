defmodule BlockScoutWeb.CurrencyHelpersTest do
  use ExUnit.Case

  alias Explorer.Chain.CurrencyHelpers

  doctest Explorer.Chain.CurrencyHelpers, import: true

  describe "format_according_to_decimals/1" do
    test "formats the amount as value considering the given decimals" do
      amount = Decimal.new(205_000_000_000_000)
      decimals = Decimal.new(12)

      assert CurrencyHelpers.format_according_to_decimals(amount, decimals) == "205"
    end

    test "considers the decimal places according to the given decimals" do
      amount = Decimal.new(205_000)
      decimals = Decimal.new(12)

      assert CurrencyHelpers.format_according_to_decimals(amount, decimals) == "0.000000205"
    end

    test "does not consider right zeros in decimal places" do
      amount = Decimal.new(90_000_000)
      decimals = Decimal.new(6)

      assert CurrencyHelpers.format_according_to_decimals(amount, decimals) == "90"
    end

    test "returns the full number when there is no right zeros in decimal places" do
      amount = Decimal.new(9_324_876)
      decimals = Decimal.new(6)

      assert CurrencyHelpers.format_according_to_decimals(amount, decimals) == "9.324876"
    end

    test "formats the value considering thousands separators" do
      amount = Decimal.new(1_000_450)
      decimals = Decimal.new(2)

      assert CurrencyHelpers.format_according_to_decimals(amount, decimals) == "10,004.5"
    end

    test "supports value as integer" do
      amount = 1_000_450
      decimals = Decimal.new(2)

      assert CurrencyHelpers.format_according_to_decimals(amount, decimals) == "10,004.5"
    end

    test "considers 0 when decimals is nil" do
      amount = 1_000_450
      decimals = nil

      assert CurrencyHelpers.format_according_to_decimals(amount, decimals) == "1,000,450"
    end
  end

  describe "format_integer_to_currency/1" do
    test "formats the integer value to a currency format" do
      assert CurrencyHelpers.format_integer_to_currency(9000) == "9,000"
    end
  end

  describe "divide_decimals/2" do
    test "divide by the given decimal amount" do
      result = CurrencyHelpers.divide_decimals(Decimal.new(1000), Decimal.new(3))
      expected_result = Decimal.new(1)
      assert Decimal.compare(result, expected_result) == :eq
    end

    test "work when number of decimals is bigger than the number's digits" do
      result = CurrencyHelpers.divide_decimals(Decimal.new(1000), Decimal.new(5))
      expected_result = Decimal.from_float(0.01)
      assert Decimal.compare(result, expected_result) == :eq
    end

    test "return the same number when number of decimals is 0" do
      result = CurrencyHelpers.divide_decimals(Decimal.new(1000), Decimal.new(0))
      expected_result = Decimal.new(1000)
      assert Decimal.compare(result, expected_result) == :eq
    end
  end
end
