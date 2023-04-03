defmodule Explorer.Counters.ContractsCounterTest do
  use Explorer.DataCase

  alias Explorer.Counters.ContractsCounter
  alias Explorer.Chain
  alias Explorer.Chain.Transaction

  test "populates the cache with the number of all contracts" do
    insert(:address, contract_code: "0x608060")
    insert(:address, contract_code: "0x608060")
    insert(:address, contract_code: "0x608060", inserted_at: Timex.shift(Timex.now(), days: -2))
    insert(:smart_contract)

    start_supervised!(ContractsCounter)
    ContractsCounter.consolidate()

    assert Chain.count_contracts_from_cache() == 4
  end

  test "populates the cache with the number of new contracts (last 24h)" do
    :transaction
    |> insert(created_contract_code_indexed_at: Timex.shift(Timex.now(), hours: -1))
    |> with_block(status: :ok)

    :transaction
    |> insert(created_contract_code_indexed_at: Timex.shift(Timex.now(), hours: -25))
    |> with_block(status: :ok)

    :transaction
    |> insert(created_contract_code_indexed_at: Timex.shift(Timex.now(), hours: -23))
    |> with_block(status: :ok)

    :transaction
    |> insert(created_contract_code_indexed_at: Timex.shift(Timex.now(), hours: -30))
    |> with_block(status: :ok)

    start_supervised!(ContractsCounter)
    ContractsCounter.consolidate()

    assert Chain.count_new_contracts_from_cache() == 2
  end

  test "populates the cache with the number of verified contracts" do
    insert(:smart_contract)
    insert(:smart_contract)
    insert(:smart_contract, inserted_at: Timex.shift(Timex.now(), days: -2))

    start_supervised!(ContractsCounter)
    ContractsCounter.consolidate()

    assert Chain.count_verified_contracts_from_cache() == 3
  end

  test "populates the cache with the number of new verified contracts (last 24h)" do
    insert(:smart_contract, inserted_at: Timex.shift(Timex.now(), hours: -25))
    insert(:smart_contract, inserted_at: Timex.shift(Timex.now(), hours: -1))
    insert(:smart_contract, inserted_at: Timex.shift(Timex.now(), hours: -23))
    insert(:smart_contract, inserted_at: Timex.shift(Timex.now(), hours: -30))

    start_supervised!(ContractsCounter)
    ContractsCounter.consolidate()

    assert Chain.count_new_verified_contracts_from_cache() == 2
  end
end
