defmodule EthereumJSONRPC.Utility.RangesHelperTest do
  use ExUnit.Case, async: true

  alias EthereumJSONRPC.Utility.RangesHelper

  describe "sanitize_ranges/1" do
    test "list of ranges" do
      assert RangesHelper.sanitize_ranges([1..2, 1..4, 3..6, 7..9, 11..12]) == [1..9, 11..12]
      assert RangesHelper.sanitize_ranges([10..7//-1, 6..4//-1, 3..1//-1]) == [10..1//-1]
      assert RangesHelper.sanitize_ranges([10..7//-1, 5..3//-1]) == [5..3//-1, 10..7//-1]
      assert RangesHelper.sanitize_ranges([1..3, 7..9, 5..6]) == [1..3, 5..9]
      assert RangesHelper.sanitize_ranges([1..3, 5..7, 4..4]) == [1..7]
      assert RangesHelper.sanitize_ranges([]) == []
    end
  end

  describe "parse_block_ranges/1" do
    test "ranges string" do
      assert RangesHelper.parse_block_ranges("100..200,300..400,500..latest") == [100..200, 300..400, 500]
      assert RangesHelper.parse_block_ranges("100..200,150..300") == [100..300]
      assert RangesHelper.parse_block_ranges("") == []
    end
  end
end
