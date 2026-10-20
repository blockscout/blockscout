# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Chain.Cache.AddressTagsTest do
  use Explorer.DataCase, async: false

  alias Explorer.Chain.Cache.AddressTags

  setup do
    config = Application.get_env(:explorer, AddressTags) || []
    Application.put_env(:explorer, AddressTags, Keyword.merge(config, enabled: true))
    on_exit(fn -> Application.put_env(:explorer, AddressTags, config) end)

    :ok
  end

  describe "fetch/2" do
    test "returns an empty list for no address hashes without calling the fallback" do
      assert AddressTags.fetch([], fn hashes ->
               send(self(), {:fallback, hashes})
               []
             end) == []

      refute_received {:fallback, _}
    end

    test "calls the fallback only for addresses missing from the cache" do
      tagged_hash = build(:address).hash
      untagged_hash = build(:address).hash
      new_hash = build(:address).hash
      tag = %{label: "label", display_name: "Label", address_hash: tagged_hash}

      fallback = fn hashes ->
        send(self(), {:fallback, Enum.sort(hashes)})
        for hash <- hashes, hash == tagged_hash, do: tag
      end

      assert AddressTags.fetch([tagged_hash, untagged_hash], fallback) == [tag]
      assert_received {:fallback, hashes}
      assert hashes == Enum.sort([tagged_hash, untagged_hash])

      # the tagged address and the address without tags are both cached now
      assert AddressTags.fetch([tagged_hash, untagged_hash, new_hash], fallback) == [tag]
      assert_received {:fallback, [^new_hash]}
    end

    test "serves a cached address without touching the fallback" do
      hash = build(:address).hash
      tag = %{label: "label", display_name: "Label", address_hash: hash}

      assert AddressTags.fetch([hash], fn _ -> [tag] end) == [tag]

      assert AddressTags.fetch([hash], fn hashes ->
               send(self(), {:fallback, hashes})
               []
             end) == [tag]

      refute_received {:fallback, _}
    end

    test "passes every address to the fallback when disabled" do
      Application.put_env(
        :explorer,
        AddressTags,
        Keyword.merge(Application.get_env(:explorer, AddressTags), enabled: false)
      )

      hash = build(:address).hash

      assert AddressTags.fetch([hash], fn hashes ->
               send(self(), {:fallback, hashes})
               []
             end) == []

      assert_received {:fallback, [^hash]}

      assert AddressTags.fetch([hash], fn hashes ->
               send(self(), {:fallback, hashes})
               []
             end) == []

      assert_received {:fallback, [^hash]}
    end
  end
end
