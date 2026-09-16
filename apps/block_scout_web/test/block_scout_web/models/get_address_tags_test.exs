# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule BlockScoutWeb.Models.GetAddressTagsTest do
  use BlockScoutWeb.ConnCase, async: false

  alias BlockScoutWeb.Models.GetAddressTags

  describe "get_tags_on_address/2" do
    test "returns the public tags of the address except the validator one" do
      address = insert(:address)
      tag = insert(:address_tag, label: "exchange", display_name: "Exchange")
      insert(:address_to_tag, address: address, tag: tag)
      validator_tag = insert(:address_tag, label: "validator", display_name: "Validator")
      insert(:address_to_tag, address: address, tag: validator_tag)

      assert GetAddressTags.get_tags_on_address(address.hash) == [
               %{label: "exchange", display_name: "Exchange", address_hash: address.hash}
             ]
    end

    test "returns an empty list for an address without tags" do
      assert GetAddressTags.get_tags_on_address(insert(:address).hash) == []
    end
  end

  describe "get_address_tags_batch/3" do
    test "groups public tags by address and fills in addresses without tags" do
      tagged = insert(:address)
      untagged = insert(:address)
      tag = insert(:address_tag, label: "bridge", display_name: "Bridge")
      insert(:address_to_tag, address: tagged, tag: tag)

      assert GetAddressTags.get_address_tags_batch([tagged.hash, untagged.hash], nil) == %{
               tagged.hash => %{
                 common_tags: [%{label: "bridge", display_name: "Bridge", address_hash: tagged.hash}],
                 personal_tags: [],
                 watchlist_names: []
               },
               untagged.hash => %{common_tags: [], personal_tags: [], watchlist_names: []}
             }
    end
  end
end
