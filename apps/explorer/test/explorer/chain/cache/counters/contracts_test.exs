defmodule Explorer.Chain.Cache.Counters.ContractsTest do
  use Explorer.DataCase

  alias Explorer.Chain.Cache.Counters.ContractsCount
  alias Explorer.Chain

  test "populates the cache with the number of all contracts" do
    insert(:address, contract_code: "0x608060")
    insert(:address, contract_code: "0x608060")
    insert(:address, contract_code: "0x608060", inserted_at: Timex.shift(Timex.now(), days: -2))
    insert(:smart_contract)

    start_supervised!(ContractsCount)
    ContractsCount.consolidate()

    assert Chain.count_contracts_from_cache() == Decimal.new(4)
  end
end
