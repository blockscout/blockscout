defmodule Explorer.Chain.Block.RangeTest do
  use ExUnit.Case

  alias Explorer.Chain.Block.Range
  alias Postgrex.Range, as: PGRange

  doctest Explorer.Chain.Block.Range, import: true

  describe "cast/1" do
    test "with negative infinity lower bound and integer" do
      assert Range.cast({nil, 2}) == {:ok, %Range{from: :negative_infinity, to: 2}}
    end

    test "with integer and infinity upper bound" do
      assert Range.cast({2, nil}) == {:ok, %Range{from: 2, to: :infinity}}
    end

    test "with two integers" do
      assert Range.cast({2, 10}) == {:ok, %Range{from: 2, to: 10}}
    end

    test "with a string" do
      assert Range.cast("[2,10]") == {:ok, %Range{from: 2, to: 10}}
      assert Range.cast("(2,10)") == {:ok, %Range{from: 3, to: 9}}
      assert Range.cast("[2,)") == {:ok, %Range{from: 2, to: :infinity}}
      assert Range.cast("(,10]") == {:ok, %Range{from: :negative_infinity, to: 10}}
      assert Range.cast("{2,10}") == :error
    end

    test "with a block range" do
      range = %Range{from: 2, to: 10}
      assert Range.cast(range) == {:ok, range}
    end

    test "with an invalid input" do
      assert Range.cast(2..10) == :error
    end
  end

  describe "load/1" do
    test "with inclusive finite bounds on Range" do
      range = %PGRange{
        lower: 2,
        lower_inclusive: true,
        upper: 10,
        upper_inclusive: true
      }

      assert Range.load(range) == {:ok, %Range{from: 2, to: 10}}
    end

    test "with non-inclusive finite bounds on Range" do
      range = %PGRange{
        lower: 2,
        lower_inclusive: false,
        upper: 10,
        upper_inclusive: false
      }

      assert Range.load(range) == {:ok, %Range{from: 3, to: 9}}
    end

    test "with infinite bounds" do
      range = %PGRange{
        lower: nil,
        lower_inclusive: false,
        upper: nil,
        upper_inclusive: false
      }

      assert Range.load(range) == {:ok, %Range{from: :negative_infinity, to: :infinity}}
    end

    test "with an invalid input" do
      assert Range.load("invalid") == :error
    end
  end

  describe "dump/1" do
    test "with infinite bounds" do
      expected = %PGRange{
        lower: nil,
        lower_inclusive: false,
        upper: nil,
        upper_inclusive: false
      }

      assert Range.dump(%Range{from: :negative_infinity, to: :infinity}) == {:ok, expected}
    end

    test "with finite bounds" do
      expected = %PGRange{
        lower: 2,
        lower_inclusive: true,
        upper: 10,
        upper_inclusive: true
      }

      assert Range.dump(%Range{from: 2, to: 10}) == {:ok, expected}
    end

    test "with an invalid input" do
      assert Range.dump("invalid") == :error
    end
  end

  test "type/0" do
    assert Range.type() == :int8range
  end
end
