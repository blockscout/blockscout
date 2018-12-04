defmodule Explorer.Chain.AddressTest do
  use Explorer.DataCase

  alias Explorer.Chain.Address
  alias Explorer.Repo

  describe "changeset/2" do
    test "with valid attributes" do
      params = params_for(:address)
      changeset = Address.changeset(%Address{}, params)
      assert changeset.valid?
    end

    test "with invalid attributes" do
      changeset = Address.changeset(%Address{}, %{dog: "woodstock"})
      refute changeset.valid?
    end
  end

  describe "count_with_fetched_coin_balance/0" do
    test "returns the number of addresses with fetched_coin_balance greater than 0" do
      insert(:address, fetched_coin_balance: 0)
      insert(:address, fetched_coin_balance: 1)
      insert(:address, fetched_coin_balance: 2)

      assert Repo.one(Address.count_with_fetched_coin_balance()) == 2
    end
  end
end
