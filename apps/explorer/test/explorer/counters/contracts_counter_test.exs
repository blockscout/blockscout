defmodule Explorer.Counters.ContractsCounterTest do
  use Explorer.DataCase

  alias Explorer.Counters.ContractsCounter
  alias Explorer.Chain

  test "populates the cache with the number of all contracts" do
    insert(:address, contract_code: "0x608060")
    insert(:address, contract_code: "0x608060")
    insert(:address, contract_code: "0x608060", inserted_at: Timex.shift(Timex.now(), days: -2))
    insert(:smart_contract)

    start_supervised!(ContractsCounter)
    ContractsCounter.consolidate()

    assert Chain.count_contracts_from_cache() == 4
  end
end
