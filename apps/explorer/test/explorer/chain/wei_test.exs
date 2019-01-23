defmodule Explorer.Chain.WeiTest do
  use ExUnit.Case, async: true

  alias Explorer.Chain.Wei

  doctest Wei

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

  describe "sum/1" do
    test "with two positive values return the sum of them" do
      first = %Wei{value: Decimal.new(123)}
      second = %Wei{value: Decimal.new(1_000)}

      assert Wei.sum(first, second) == %Wei{value: Decimal.new(1_123)}
    end

    test "with a positive and a negative value return the positive minus the negative's absolute" do
      first = %Wei{value: Decimal.new(123)}
      second = %Wei{value: Decimal.new(-100)}

      assert Wei.sum(first, second) == %Wei{value: Decimal.new(23)}
    end
  end

  describe "sub/1" do
    test "with a negative second parameter return the sum of the absolute values" do
      first = %Wei{value: Decimal.new(123)}
      second = %Wei{value: Decimal.new(-100)}

      assert Wei.sub(first, second) == %Wei{value: Decimal.new(223)}
    end

    test "with a negative first parameter return the negative of the sum of the absolute values" do
      first = %Wei{value: Decimal.new(-123)}
      second = %Wei{value: Decimal.new(100)}

      assert Wei.sub(first, second) == %Wei{value: Decimal.new(-223)}
    end

    test "with a larger first parameter return a positive number" do
      first = %Wei{value: Decimal.new(123)}
      second = %Wei{value: Decimal.new(100)}

      assert Wei.sub(first, second) == %Wei{value: Decimal.new(23)}
    end

    test "with a larger second parameter return a negative number" do
      first = %Wei{value: Decimal.new(23)}
      second = %Wei{value: Decimal.new(100)}

      assert Wei.sub(first, second) == %Wei{value: Decimal.new(-77)}
    end
  end

  describe "mult/2" do
    test "with positive Wei and positive multiplier returns positive Wei" do
      wei = %Wei{value: Decimal.new(123)}
      multiplier = 100

      assert Wei.mult(wei, multiplier) == %Wei{value: Decimal.new(12300)}
    end

    test "with positive Wei and negative multiplier returns positive Wei" do
      wei = %Wei{value: Decimal.new(123)}
      multiplier = -1

      assert Wei.mult(wei, multiplier) == %Wei{value: Decimal.new(-123)}
    end

    test "with negative Wei and positive multiplier returns negative Wei" do
      wei = %Wei{value: Decimal.new(-123)}
      multiplier = 100

      assert Wei.mult(wei, multiplier) == %Wei{value: Decimal.new(-12300)}
    end

    test "with negative Wei and negative multiplier returns positive Wei" do
      wei = %Wei{value: Decimal.new(-123)}
      multiplier = -100

      assert Wei.mult(wei, multiplier) == %Wei{value: Decimal.new(12300)}
    end
  end
end
