defmodule Explorer.Counters.VerifiedContractsCounterTest do
  use Explorer.DataCase

  alias Explorer.Counters.VerifiedContractsCounter
  alias Explorer.Chain
  alias Explorer.Chain.Transaction

  test "populates the cache with the number of verified contracts" do
    insert(:smart_contract)
    insert(:smart_contract)
    insert(:smart_contract, inserted_at: Timex.shift(Timex.now(), days: -2))

    start_supervised!(VerifiedContractsCounter)
    VerifiedContractsCounter.consolidate()

    assert Chain.count_verified_contracts_from_cache() == 3
  end
end
