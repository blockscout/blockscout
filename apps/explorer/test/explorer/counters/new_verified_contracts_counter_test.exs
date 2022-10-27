defmodule Explorer.Counters.NewVerifiedContractsCounterTest do
  use Explorer.DataCase

  alias Explorer.Counters.NewVerifiedContractsCounter
  alias Explorer.Chain

  test "populates the cache with the number of new verified contracts (last 24h)" do
    insert(:smart_contract, inserted_at: Timex.shift(Timex.now(), hours: -25))
    insert(:smart_contract, inserted_at: Timex.shift(Timex.now(), hours: -1))
    insert(:smart_contract, inserted_at: Timex.shift(Timex.now(), hours: -23))
    insert(:smart_contract, inserted_at: Timex.shift(Timex.now(), hours: -30))

    start_supervised!(NewVerifiedContractsCounter)
    NewVerifiedContractsCounter.consolidate()

    assert Chain.count_new_verified_contracts_from_cache() == 2
  end
end
