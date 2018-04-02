defmodule Explorer.AddressTest do
  use Explorer.DataCase
  alias Explorer.Address

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

    test "it downcases hashes on the way in" do
      params = params_for(:address, hash: "0xALLCAPS")
      changeset = Address.changeset(%Address{}, params)
      assert Ecto.Changeset.get_change(changeset, :hash) == "0xallcaps"
    end
  end

  describe "balance_changeset/2" do
    test "with a new balance" do
      changeset = Address.balance_changeset(%Address{}, %{balance: 99})
      assert changeset.valid?
    end

    test "with other attributes" do
      changeset = Address.balance_changeset(%Address{}, %{hash: "0xraisinets"})
      refute changeset.valid?
    end
  end
end
