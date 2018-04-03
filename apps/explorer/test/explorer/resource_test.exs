defmodule Explorer.ResourceTest do
  use Explorer.DataCase

  alias Explorer.Resource

  describe "lookup/1" do
    test "finds a block by block number with a valid block number" do
      insert(:block, number: 37)
      block = Resource.lookup("37")

      assert block.number == 37
    end

    test "finds a transaction by hash" do
      transaction = insert(:transaction)

      resource = Resource.lookup(transaction.hash)

      assert transaction.hash == resource.hash
    end

    test "finds an address by hash" do
      address = insert(:address)

      resource = Resource.lookup(address.hash)

      assert address.hash == resource.hash
    end

    test "returns nil when garbage is passed in" do
      item = Resource.lookup("any ol' thing")

      assert is_nil(item)
    end

    test "returns nil when it does not find a match" do
      transaction_hash = String.pad_trailing("0xnonsense", 43, "0")
      address_hash = String.pad_trailing("0xbaddress", 42, "0")

      assert is_nil(Resource.lookup("38999"))
      assert is_nil(Resource.lookup(transaction_hash))
      assert is_nil(Resource.lookup(address_hash))
    end
  end
end
