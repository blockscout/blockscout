defmodule Explorer.Chain.AddressTest do
  use Explorer.DataCase

  alias Ecto.Changeset
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
      changeset =
        Address.balance_changeset(%Address{}, %{
          hash: "0x0000000000000000000000000000000000000001",
          fetched_balance: 99,
          fetched_balance_block_number: 1
        })

      assert changeset.valid?
    end

    test "hash, fetched_balance, and fetched_balance_block_number are required" do
      assert %Changeset{errors: errors, valid?: false} = Address.balance_changeset(%Address{}, %{})
      assert Keyword.get_values(errors, :hash) == [{"can't be blank", [validation: :required]}]
      assert Keyword.get_values(errors, :fetched_balance) == [{"can't be blank", [validation: :required]}]
      assert Keyword.get_values(errors, :fetched_balance_block_number) == [{"can't be blank", [validation: :required]}]
    end
  end
end
