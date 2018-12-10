defmodule Explorer.Counters.AddessesWithBalanceCounterTest do
  use Explorer.DataCase

  alias Explorer.Counters.AddessesWithBalanceCounter

  test "populates the cache with the number of addresses with fetched coin balance greater than 0" do
    insert(:address, fetched_coin_balance: 0)
    insert(:address, fetched_coin_balance: 1)
    insert(:address, fetched_coin_balance: 2)

    AddessesWithBalanceCounter.consolidate()

    assert AddessesWithBalanceCounter.fetch() == 2
  end
end
