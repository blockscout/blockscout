defmodule Explorer.Counters.FreshPendingTransactionsCounterTest do
  use Explorer.DataCase

  alias Explorer.Counters.FreshPendingTransactionsCounter

  test "populates the cache with the number of pending transactions addresses" do
    insert(:transaction)
    insert(:transaction)
    insert(:transaction)

    start_supervised!(FreshPendingTransactionsCounter)
    FreshPendingTransactionsCounter.consolidate()

    assert FreshPendingTransactionsCounter.fetch([]) == Decimal.new("3")
  end

  test "count only fresh transactions" do
    insert(:transaction, inserted_at: Timex.shift(Timex.now(), hours: -2))
    insert(:transaction)
    insert(:transaction)

    start_supervised!(FreshPendingTransactionsCounter)
    FreshPendingTransactionsCounter.consolidate()

    assert FreshPendingTransactionsCounter.fetch([]) == Decimal.new("2")
  end
end
