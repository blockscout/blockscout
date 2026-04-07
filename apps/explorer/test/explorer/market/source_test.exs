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
end
