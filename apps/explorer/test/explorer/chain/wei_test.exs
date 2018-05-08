defmodule Explorer.Chain.WeiTest do
  use ExUnit.Case, async: true
  alias Explorer.Chain.Wei

  doctest Explorer.Chain.Wei

  describe "cast/1" do
    test "with hex string" do
      assert Wei.cast("0x142") == {:ok, %Wei{value: Decimal.new(322)}}
      assert Wei.cast("0xzzz") == :error
    end

    test "with integer string" do
      assert Wei.cast("123") == {:ok, %Wei{value: Decimal.new(123)}}
      assert Wei.cast("123.5") == :error
      assert Wei.cast("invalid") == :error
    end

    test "with integer" do
      assert Wei.cast(123) == {:ok, %Wei{value: Decimal.new(123)}}
    end

    test "with decimal" do
      decimal = Decimal.new(123)
      assert Wei.cast(decimal) == {:ok, %Wei{value: decimal}}
    end

    test "with Wei struct" do
      wei = %Wei{value: Decimal.new(123)}
      assert Wei.cast(wei) == {:ok, wei}
    end

    test "with unsupported type" do
      assert Wei.cast(nil) == :error
    end
  end

  describe "dump/1" do
    test "with Wei struct" do
      decimal = Decimal.new(123)
      assert Wei.dump(%Wei{value: decimal}) == {:ok, decimal}
    end

    test "with invalid value" do
      assert Wei.dump(123) == :error
    end
  end

  test "load/1" do
    decimal = Decimal.new(123)
    assert Wei.load(decimal) == {:ok, %Wei{value: decimal}}
  end

  test "type/0" do
    assert Wei.type() == :decimal
  end
end
