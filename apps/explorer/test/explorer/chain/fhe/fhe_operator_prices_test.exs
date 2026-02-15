defmodule Explorer.Chain.FheOperatorPricesTest do
  use ExUnit.Case, async: true

  alias Explorer.Chain.FheOperatorPrices

  describe "get_price/3" do
    test "returns correct price for scalar FheAdd operation" do
      assert 84_000 == FheOperatorPrices.get_price("fheAdd", "Uint8", true)
      assert 93_000 == FheOperatorPrices.get_price("fheAdd", "Uint16", true)
      assert 95_000 == FheOperatorPrices.get_price("fheAdd", "Uint32", true)
    end

    test "returns correct price for non-scalar FheAdd operation" do
      assert 88_000 == FheOperatorPrices.get_price("fheAdd", "Uint8", false)
      assert 93_000 == FheOperatorPrices.get_price("fheAdd", "Uint16", false)
      assert 125_000 == FheOperatorPrices.get_price("fheAdd", "Uint32", false)
    end

    test "returns correct price for FheMul operation" do
      assert 122_000 == FheOperatorPrices.get_price("fheMul", "Uint8", true)
      assert 150_000 == FheOperatorPrices.get_price("fheMul", "Uint8", false)
      assert 1_686_000 == FheOperatorPrices.get_price("fheMul", "Uint128", false)
    end

    test "returns correct price for FheDiv operation" do
      assert 210_000 == FheOperatorPrices.get_price("fheDiv", "Uint8", true)
      assert 1_225_000 == FheOperatorPrices.get_price("fheDiv", "Uint128", true)
    end

    test "returns correct price for bitwise operations" do
      assert 22_000 == FheOperatorPrices.get_price("fheBitAnd", "Bool", true)
      assert 25_000 == FheOperatorPrices.get_price("fheBitAnd", "Bool", false)
      assert 31_000 == FheOperatorPrices.get_price("fheBitAnd", "Uint8", true)
    end

    test "returns 0 for unknown operation" do
      assert 0 == FheOperatorPrices.get_price("unknown", "Uint8", true)
    end

    test "returns 0 for unknown FHE type" do
      assert 0 == FheOperatorPrices.get_price("fheAdd", "Unknown", true)
    end

    test "handles operations that only have scalar prices" do
      # Operations that only have scalar prices return scalar price regardless of is_scalar flag
      assert 210_000 == FheOperatorPrices.get_price("fheDiv", "Uint8", true)
      assert 210_000 == FheOperatorPrices.get_price("fheDiv", "Uint8", false)
      assert 1_225_000 == FheOperatorPrices.get_price("fheDiv", "Uint128", false)
    end

    test "handles operations with types structure (fheRand)" do
      assert 19_000 == FheOperatorPrices.get_price("fheRand", "Bool", false)
      assert 23_000 == FheOperatorPrices.get_price("fheRand", "Uint8", false)
      assert 25_000 == FheOperatorPrices.get_price("fheRand", "Uint128", false)
    end

    test "handles fheRandBounded operation" do
      assert 23_000 == FheOperatorPrices.get_price("fheRandBounded", "Uint8", false)
      assert 30_000 == FheOperatorPrices.get_price("fheRandBounded", "Uint256", false)
    end
  end

  describe "get_type_name/1" do
    test "returns correct type name for type bytes" do
      # Mapping matches fhevm ALL_FHE_TYPE_INFOS (fheTypeInfos.ts)
      assert "Bool" == FheOperatorPrices.get_type_name(0)
      assert "Uint4" == FheOperatorPrices.get_type_name(1)
      assert "Uint8" == FheOperatorPrices.get_type_name(2)
      assert "Uint16" == FheOperatorPrices.get_type_name(3)
      assert "Uint32" == FheOperatorPrices.get_type_name(4)
      assert "Uint64" == FheOperatorPrices.get_type_name(5)
      assert "Uint128" == FheOperatorPrices.get_type_name(6)
      assert "Uint160" == FheOperatorPrices.get_type_name(7)
      assert "Uint256" == FheOperatorPrices.get_type_name(8)
      assert "Uint512" == FheOperatorPrices.get_type_name(9)
      assert "Uint1024" == FheOperatorPrices.get_type_name(10)
    end

    test "returns Unknown for invalid type byte" do
      assert "Unknown" == FheOperatorPrices.get_type_name(99)
      assert "Unknown" == FheOperatorPrices.get_type_name(-1)
    end
  end
end
