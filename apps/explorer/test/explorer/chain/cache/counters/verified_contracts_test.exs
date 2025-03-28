defmodule Explorer.Chain.Cache.Counters.VerifiedContractsCountTest do
  use Explorer.DataCase

  alias Explorer.Chain.Cache.Counters.VerifiedContractsCount
  alias Explorer.Chain

  test "populates the cache with the number of verified contracts" do
    insert(:smart_contract)
    insert(:smart_contract)
    insert(:smart_contract, inserted_at: Timex.shift(Timex.now(), days: -2))

    start_supervised!(VerifiedContractsCount)
    VerifiedContractsCount.consolidate()

    assert Chain.count_verified_contracts_from_cache() == Decimal.new(3)
  end
end
