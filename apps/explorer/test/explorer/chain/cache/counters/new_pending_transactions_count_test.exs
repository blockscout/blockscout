defmodule Explorer.Chain.Cache.Counters.NewPendingTransactionsCountTest do
  use Explorer.DataCase

  alias Explorer.Chain.Cache.Counters.NewPendingTransactionsCount

  test "populates the cache with the number of pending transactions addresses" do
    insert(:transaction)
    insert(:transaction)
    insert(:transaction)

    start_supervised!(NewPendingTransactionsCount)
    NewPendingTransactionsCount.consolidate()

    assert NewPendingTransactionsCount.fetch([]) == Decimal.new("3")
  end

  test "count only fresh transactions" do
    insert(:transaction, inserted_at: Timex.shift(Timex.now(), hours: -2))
    insert(:transaction)
    insert(:transaction)

    start_supervised!(NewPendingTransactionsCount)
    NewPendingTransactionsCount.consolidate()

    assert NewPendingTransactionsCount.fetch([]) == Decimal.new("2")
  end
end
