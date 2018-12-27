defmodule Explorer.Counters.AddressesWithBalanceCounterTest do
  use Explorer.DataCase

  alias Explorer.Counters.AddressesWithBalanceCounter

  test "populates the cache with the number of addresses with fetched coin balance greater than 0" do
    insert(:address, fetched_coin_balance: 0)
    insert(:address, fetched_coin_balance: 1)
    insert(:address, fetched_coin_balance: 2)

    start_supervised!(AddressesWithBalanceCounter)
    AddressesWithBalanceCounter.consolidate()

    assert AddressesWithBalanceCounter.fetch() == 2
  end
end
