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
  end

  describe "find_or_create_by_hash/1" do
    test "that it creates a new address when one does not exist" do
      Address.find_or_create_by_hash("0xFreshPrince")
      last_address = Address |> order_by(desc: :inserted_at) |> Repo.one
      assert last_address.hash == "0xfreshprince"
    end

    test "when the address already exists it doesn't insert a new address" do
      insert(:address, %{hash: "bigmouthbillybass"})
      Address.find_or_create_by_hash("bigmouthbillybass")
      number_of_addresses = Address |> Repo.all |> length
      assert number_of_addresses == 1
    end

    test "when there is no hash it blows up" do
      assert_raise Ecto.InvalidChangesetError, fn ->
        Address.find_or_create_by_hash("")
      end
    end
  end
end
