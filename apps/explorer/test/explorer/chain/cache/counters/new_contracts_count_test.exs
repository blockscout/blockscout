defmodule Explorer.Chain.Cache.Counters.NewContractsCountTest do
  use Explorer.DataCase

  alias Explorer.Chain.Cache.Counters.NewContractsCount
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

    start_supervised!(NewContractsCount)
    NewContractsCount.consolidate()

    assert Chain.count_new_contracts_from_cache() == Decimal.new(2)
  end
end
