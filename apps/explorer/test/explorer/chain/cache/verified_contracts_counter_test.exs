defmodule Explorer.Chain.Cache.VerifiedContractsCounterTest do
  use Explorer.DataCase

  alias Explorer.Chain.Cache.VerifiedContractsCounter
  alias Explorer.Chain

  test "populates the cache with the number of verified contracts" do
    insert(:smart_contract)
    insert(:smart_contract)
    insert(:smart_contract, inserted_at: Timex.shift(Timex.now(), days: -2))

    start_supervised!(VerifiedContractsCounter)
    VerifiedContractsCounter.consolidate()

    assert Chain.count_verified_contracts_from_cache() == Decimal.new(3)
  end
end
