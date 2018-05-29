defmodule Explorer.Chain.BlockRangeTest do
  use ExUnit.Case

  alias Explorer.Chain.BlockRange
  alias Postgrex.Range

  describe "cast/1" do
    test "with negative infinity lower bound and integer" do
      assert BlockRange.cast({nil, 2}) == {:ok, %BlockRange{from: :negative_infinity, to: 2}}
    end

    test "with integer and infinity upper bound" do
      assert BlockRange.cast({2, nil}) == {:ok, %BlockRange{from: 2, to: :infinity}}
    end

    test "with two integers" do
      assert BlockRange.cast({2, 10}) == {:ok, %BlockRange{from: 2, to: 10}}
    end

    test "with a string" do
      assert BlockRange.cast("[2,10]") == {:ok, %BlockRange{from: 2, to: 10}}
      assert BlockRange.cast("(2,10)") == {:ok, %BlockRange{from: 3, to: 9}}
      assert BlockRange.cast("[2,)") == {:ok, %BlockRange{from: 2, to: :infinity}}
      assert BlockRange.cast("(,10]") == {:ok, %BlockRange{from: :negative_infinity, to: 10}}
      assert BlockRange.cast("{2,10}") == :error
    end

    test "with a block range" do
      range = %BlockRange{from: 2, to: 10}
      assert BlockRange.cast(range) == {:ok, range}
    end

    test "with an invalid input" do
      assert BlockRange.cast(2..10) == :error
    end
  end

  describe "load/1" do
    test "with inclusive finite bounds on Range" do
      range = %Range{
        lower: 2,
        lower_inclusive: true,
        upper: 10,
        upper_inclusive: true
      }

      assert BlockRange.load(range) == {:ok, %BlockRange{from: 2, to: 10}}
    end

    test "with non-inclusive finite bounds on Range" do
      range = %Range{
        lower: 2,
        lower_inclusive: false,
        upper: 10,
        upper_inclusive: false
      }

      assert BlockRange.load(range) == {:ok, %BlockRange{from: 3, to: 9}}
    end

    test "with infinite bounds" do
      range = %Range{
        lower: nil,
        lower_inclusive: false,
        upper: nil,
        upper_inclusive: false
      }

      assert BlockRange.load(range) == {:ok, %BlockRange{from: :negative_infinity, to: :infinity}}
    end

    test "with an invalid input" do
      assert BlockRange.load("invalid") == :error
    end
  end

  describe "dump/1" do
    test "with infinite bounds" do
      expected = %Range{
        lower: nil,
        lower_inclusive: false,
        upper: nil,
        upper_inclusive: false
      }

      assert BlockRange.dump(%BlockRange{from: :negative_infinity, to: :infinity}) == {:ok, expected}
    end

    test "with fininte bounds" do
      expected = %Range{
        lower: 2,
        lower_inclusive: true,
        upper: 10,
        upper_inclusive: true
      }

      assert BlockRange.dump(%BlockRange{from: 2, to: 10}) == {:ok, expected}
    end

    test "with an invalid input" do
      assert BlockRange.dump("invalid") == :error
    end
  end

  test "type/0" do
    assert BlockRange.type() == :int8range
  end
end
