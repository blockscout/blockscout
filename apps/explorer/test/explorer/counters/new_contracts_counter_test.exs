defmodule Explorer.Counters.NewContractsCounterTest do
  use Explorer.DataCase

  alias Explorer.Counters.NewContractsCounter
  alias Explorer.Chain

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

    start_supervised!(NewContractsCounter)
    NewContractsCounter.consolidate()

    assert Chain.count_new_contracts_from_cache() == 2
  end
end
