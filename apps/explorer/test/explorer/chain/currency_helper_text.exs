defmodule Explorer.Chain.CurrencyHelperTest do
  use ExUnit.Case

  alias Explorer.Chain.CurrencyHelper

  describe "divide_decimals/2" do
    test "divide by the given decimal amount" do
      result = CurrencyHelper.divide_decimals(Decimal.new(1000), Decimal.new(3))
      expected_result = Decimal.new(1)
      assert Decimal.compare(result, expected_result) == :eq
    end

    test "work when number of decimals is bigger than the number's digits" do
      result = CurrencyHelper.divide_decimals(Decimal.new(1000), Decimal.new(5))
      expected_result = Decimal.from_float(0.01)
      assert Decimal.compare(result, expected_result) == :eq
    end

    test "return the same number when number of decimals is 0" do
      result = CurrencyHelper.divide_decimals(Decimal.new(1000), Decimal.new(0))
      expected_result = Decimal.new(1000)
      assert Decimal.compare(result, expected_result) == :eq
    end
  end
end
