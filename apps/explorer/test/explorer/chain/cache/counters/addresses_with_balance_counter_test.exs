defmodule Explorer.Chain.Cache.Counters.AddressesWithBalanceCountTest do
  use Explorer.DataCase

  alias Explorer.Chain.Cache.Counters.AddressesWithBalanceCount

  test "populates the cache with the number of addresses with fetched coin balance greater than 0" do
    insert(:address, fetched_coin_balance: 0)
    insert(:address, fetched_coin_balance: 1)
    insert(:address, fetched_coin_balance: 2)

    start_supervised!(AddressesWithBalanceCount)
    AddressesWithBalanceCount.consolidate()

    assert AddressesWithBalanceCount.fetch() == 2
  end
end
