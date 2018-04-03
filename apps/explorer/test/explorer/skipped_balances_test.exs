defmodule Explorer.SkippedBalancesTest do
  use Explorer.DataCase

  alias Explorer.SkippedBalances

  describe "fetch/1" do
    test "returns a list of address hashes that do not have balances" do
      insert(:address, hash: "0xcashews", balance: nil)
      assert SkippedBalances.fetch(1) == ["0xcashews"]
    end

    test "only get a limited set of addresses" do
      insert_list(10, :address, balance: nil)
      insert_list(5, :address, balance: 55)
      assert length(SkippedBalances.fetch(7)) == 7
    end
  end
end
