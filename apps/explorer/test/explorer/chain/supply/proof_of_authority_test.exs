defmodule Explorer.Chain.Supply.ProofOfAuthorityTest do
  use Explorer.DataCase

  alias Explorer.Chain.Supply.ProofOfAuthority

  describe "total/0" do
    test "without blocks present" do
      assert ProofOfAuthority.total() == ProofOfAuthority.initial_supply()
    end

    test "with blocks present" do
      height = 2_000_000
      insert(:block, number: height)
      expected = ProofOfAuthority.initial_supply() + height

      assert ProofOfAuthority.total() == expected
    end
  end

  test "circulating/0" do
    if Date.compare(Date.utc_today(), ~D[2019-12-15]) == :lt do
      assert ProofOfAuthority.circulating() < ProofOfAuthority.total()
    else
      assert ProofOfAuthority.circulating() == ProofOfAuthority.total()
    end
  end

  test "reserved_supply/1" do
    initial_reserved = 50_492_160

    assert ProofOfAuthority.reserved_supply(~D[2018-06-14]) == initial_reserved
    assert ProofOfAuthority.reserved_supply(~D[2018-06-15]) == 37_869_120
    assert ProofOfAuthority.reserved_supply(~D[2018-09-15]) == 31_557_600
    assert ProofOfAuthority.reserved_supply(~D[2018-12-15]) == 25_246_080
    assert ProofOfAuthority.reserved_supply(~D[2019-03-15]) == 18_934_560
    assert ProofOfAuthority.reserved_supply(~D[2019-06-15]) == 12_623_040
    assert ProofOfAuthority.reserved_supply(~D[2019-09-15]) == 6_311_520
    assert ProofOfAuthority.reserved_supply(~D[2019-12-15]) == 0
  end
end
