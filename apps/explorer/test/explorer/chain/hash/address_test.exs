defmodule Explorer.Chain.Hash.AddressTest do
  use ExUnit.Case, async: true

  doctest Explorer.Chain.Hash.Address

  alias Explorer.Chain.Hash.Address

  describe "validate/1" do
    test "with valid uppercase hash" do
      assert Address.validate("0xC1912FEE45D61C87CC5EA59DAE31190FFFFF232D") ==
               {:ok, "0xC1912FEE45D61C87CC5EA59DAE31190FFFFF232D"}
    end

    test "with valid lowercase hash" do
      assert Address.validate("0xc1912fee45d61c87cc5ea59dae31190fffff232d") ==
               {:ok, "0xc1912fee45d61c87cc5ea59dae31190fffff232d"}
    end

    test "with valid checksummed hash" do
      assert Address.validate("0xc1912fEE45d61C87Cc5EA59DaE31190FFFFf232d") ==
               {:ok, "0xc1912fEE45d61C87Cc5EA59DaE31190FFFFf232d"}
    end

    test "with invalid checksum hash" do
      assert Address.validate("0xC1912fEE45d61C87Cc5EA59DaE31190FFFFf232d") == {:error, :invalid_checksum}
    end

    test "with non-hex string" do
      assert Address.validate("0xc1912fEE45d61C87Cc5EA59DaE31190FFFFf232H") == {:error, :invalid_characters}
    end

    test "with invalid length string" do
      assert Address.validate("0xc1912fEE45d61C87Cc5EA59DaE31190FFFFf232") == {:error, :invalid_length}
    end
  end
end
