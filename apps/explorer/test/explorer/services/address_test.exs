defmodule Explorer.Address.ServiceTest do
  use Explorer.DataCase

  alias Explorer.Address.Service
  alias Explorer.Address

  describe "by_hash/1" do
    test "it returns an address with that hash" do
      address = insert(:address, hash: "0xandesmints")
      result = Service.by_hash("0xandesmints")
      assert result.id == address.id
    end
  end

  describe "update_balance/2" do
    test "it updates the balance" do
      insert(:address, hash: "0xwarheads")
      Service.update_balance(5, "0xwarheads")
      result = Service.by_hash("0xwarheads")
      assert result.balance == Decimal.new(5)
    end

    test "it updates the balance timestamp" do
      insert(:address, hash: "0xtwizzlers")
      Service.update_balance(88, "0xtwizzlers")
      result = Service.by_hash("0xtwizzlers")
      refute is_nil(result.balance_updated_at)
    end

    test "it creates an address if one does not exist" do
      Service.update_balance(88, "0xtwizzlers")
      result = Service.by_hash("0xtwizzlers")
      assert result.balance == Decimal.new(88)
    end
  end

  describe "find_or_create_by_hash/1" do
    test "that it creates a new address when one does not exist" do
      Service.find_or_create_by_hash("0xFreshPrince")
      assert Service.by_hash("0xfreshprince")
    end

    test "when the address already exists it doesn't insert a new address" do
      insert(:address, %{hash: "bigmouthbillybass"})
      Service.find_or_create_by_hash("bigmouthbillybass")
      number_of_addresses = Address |> Repo.all() |> length
      assert number_of_addresses == 1
    end

    test "when there is no hash it blows up" do
      assert_raise Ecto.InvalidChangesetError, fn ->
        Service.find_or_create_by_hash("")
      end
    end
  end
end
