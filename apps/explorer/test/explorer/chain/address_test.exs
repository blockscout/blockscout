defmodule Explorer.Chain.AddressTest do
  use Explorer.DataCase

  alias Explorer.Chain.Address

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
