defmodule Explorer.Tags.AddressToTagTest do
  use Explorer.DataCase

  alias Explorer.Repo
  alias Explorer.Tags.AddressToTag

  describe "set_tag_to_addresses/2" do
    test "does not remove existing address" do
      address = insert(:address, hash: "0x3078000000000000000000000000000000000001")
      address_hash = address.hash
      tag = insert(:address_tag)
      tag_id = tag.id
      att = insert(:address_to_tag, tag_id: tag.id, tag: tag, address_hash: address.hash, address: address)
      att_inserted_at = att.inserted_at

      :timer.sleep(100)

      AddressToTag.set_tag_to_addresses(tag.id, [to_string(address_hash)])

      # timestamp should be the same, no need to delete and reinsert the same address
      assert [%AddressToTag{tag_id: ^tag_id, address_hash: ^address_hash, inserted_at: ^att_inserted_at}] =
               Repo.all(AddressToTag)
    end
  end
end
