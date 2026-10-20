# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Chain.Cache.ScamAddressesTest do
  use Explorer.DataCase, async: false

  alias Explorer.Chain.Address.{Reputation, ScamBadgeToAddress}
  alias Explorer.Chain.Cache.ScamAddresses

  describe "scam_hashes/1" do
    test "falls back to the database while the cache is not running" do
      %{address_hash: badged_hash} = insert(:scam_badge_to_address)
      clean_hash = insert(:address).hash

      assert ScamAddresses.scam_hashes([badged_hash, clean_hash]) == MapSet.new([badged_hash])
    end

    test "answers from the cache once it is loaded" do
      %{address_hash: badged_hash} = insert(:scam_badge_to_address)
      clean_hash = insert(:address).hash

      start_cache()

      # only a cached answer can still see a badge that is no longer in the database
      Repo.delete_all(ScamBadgeToAddress)

      assert ScamAddresses.scam_hashes([badged_hash, clean_hash]) == MapSet.new([badged_hash])
    end

    test "returns an empty set for no address hashes" do
      assert ScamAddresses.scam_hashes([]) == MapSet.new()
    end

    test "goes back to the database when the table outgrows the size limit" do
      %{address_hash: badged_hash} = insert(:scam_badge_to_address)

      start_cache()
      assert ScamAddresses.scam?(badged_hash)

      analyze_badges()
      put_max_size(0)
      ScamAddresses.reload()

      # nothing is cached any more, so the row going away is visible at once
      Repo.delete_all(ScamBadgeToAddress)

      refute ScamAddresses.scam?(badged_hash)
    end
  end

  describe "badge changes" do
    test "assigning a badge fills the cache" do
      address_hash = insert(:address).hash

      start_cache()
      refute ScamAddresses.scam?(address_hash)

      ScamBadgeToAddress.add([to_string(address_hash)])

      assert ScamAddresses.scam?(address_hash)
    end

    test "revoking a badge drops it from the cache" do
      %{address_hash: address_hash} = insert(:scam_badge_to_address)

      start_cache()
      assert ScamAddresses.scam?(address_hash)

      ScamBadgeToAddress.delete([address_hash])

      refute ScamAddresses.scam?(address_hash)
    end
  end

  describe "preload_reputation/1" do
    setup do
      put_test_env(:block_scout_web, :hide_scam_addresses, true)
    end

    test "marks cached addresses as scam" do
      %{address_hash: badged_hash} = insert(:scam_badge_to_address)
      clean_hash = insert(:address).hash

      start_cache()
      Repo.delete_all(ScamBadgeToAddress)

      assert [{^badged_hash, %Reputation{reputation: "scam"}}, {^clean_hash, %Reputation{reputation: "ok"}}] =
               Reputation.preload_reputation([badged_hash, clean_hash])
    end
  end

  # The cache loads itself on start, and `reload/0` is synchronous, so waiting on
  # it is enough to know the table is filled.
  defp start_cache do
    start_supervised!(ScamAddresses)

    ScamAddresses.reload()
  end

  defp put_max_size(max_size) do
    config = Application.get_env(:explorer, ScamAddresses, [])

    put_test_env(:explorer, ScamAddresses, Keyword.merge(config, max_size: max_size))
  end

  # A setting that was not configured has to be restored as not configured —
  # putting back the `nil` that `get_env/2` reports would shadow the defaults
  # every later `get_env/3` passes.
  defp put_test_env(app, key, value) do
    initial_config = Application.fetch_env(app, key)

    Application.put_env(app, key, value)

    on_exit(fn ->
      case initial_config do
        {:ok, initial_value} -> Application.put_env(app, key, initial_value)
        :error -> Application.delete_env(app, key)
      end
    end)
  end

  # The size guard reads `pg_class` statistics, which a table this fresh has none
  # of — without an `ANALYZE` the estimate is `nil` and the guard lets it through.
  defp analyze_badges do
    Repo.query!("ANALYZE #{ScamBadgeToAddress.__schema__(:source)}")
  end
end
