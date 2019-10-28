defmodule Explorer.Counters.AddressesCounterTest do
  use Explorer.DataCase

  alias Explorer.Counters.AddressesCounter

  test "populates the cache with the number of all addresses" do
    insert(:address, fetched_coin_balance: 0)
    insert(:address, fetched_coin_balance: 1)
    insert(:address, fetched_coin_balance: 2)

    start_supervised!(AddressesCounter)
    AddressesCounter.consolidate()

    assert AddressesCounter.fetch() == 3
  end
end
