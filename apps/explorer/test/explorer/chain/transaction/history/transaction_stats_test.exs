defmodule Explorer.Chain.Transaction.History.TransactionStatsTest do
  use Explorer.DataCase, async: false

  alias Explorer.Chain.Transaction.History.TransactionStats
  alias Explorer.Repo

  test "by_date_range()" do
    some_transaction_stats = [
      %{date: ~D[2019-07-09], number_of_transactions: 10},
      %{date: ~D[2019-07-08], number_of_transactions: 20},
      %{date: ~D[2019-07-07], number_of_transactions: 30}
    ]

    Repo.insert_all(TransactionStats, some_transaction_stats)

    all3 = TransactionStats.by_date_range(~D[2019-07-07], ~D[2019-07-09])
    assert 3 = length(all3)

    assert ~D[2019-07-09] = Enum.at(all3, 0).date
    assert 10 == Enum.at(all3, 0).number_of_transactions
    assert ~D[2019-07-08] = Enum.at(all3, 1).date
    assert 20 == Enum.at(all3, 1).number_of_transactions
    assert ~D[2019-07-07] = Enum.at(all3, 2).date
    assert 30 == Enum.at(all3, 2).number_of_transactions

    just2 = TransactionStats.by_date_range(~D[2019-07-08], ~D[2019-07-09])
    assert 2 == length(just2)
    assert ~D[2019-07-08] = Enum.at(just2, 1).date
  end
end
