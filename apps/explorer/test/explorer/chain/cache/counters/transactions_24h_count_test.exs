defmodule Explorer.Chain.Cache.Counters.Transactions24hCountTest do
  use Explorer.DataCase

  alias Explorer.Chain.Cache.Counters.Transactions24hCount

  test "populates the cache with transaction counters" do
    block = insert(:block, base_fee_per_gas: 50)
    address = insert(:address)

    # fee = 10000

    insert(:transaction,
      from_address: address,
      block: block,
      block_number: block.number,
      cumulative_gas_used: 0,
      index: 0,
      gas_price: 100,
      gas_used: 100
    )

    # fee = 15000

    insert(:transaction,
      from_address: address,
      block: block,
      block_number: block.number,
      cumulative_gas_used: 100,
      index: 1,
      gas_price: 150,
      gas_used: 100,
      max_priority_fee_per_gas: 100,
      max_fee_per_gas: 200
    )

    # fee = 10000

    insert(:transaction,
      from_address: address,
      block: block,
      block_number: block.number,
      cumulative_gas_used: 200,
      index: 2,
      gas_price: 100,
      gas_used: 100,
      max_priority_fee_per_gas: 70,
      max_fee_per_gas: 100
    )

    start_supervised!(Transactions24hCount)
    Transactions24hCount.consolidate()

    transaction_count = Transactions24hCount.fetch_count([])
    transaction_fee_sum = Transactions24hCount.fetch_fee_sum([])
    transaction_fee_average = Transactions24hCount.fetch_fee_average([])

    assert transaction_count == Decimal.new("3")
    assert transaction_fee_sum == Decimal.new("35000")
    assert transaction_fee_average == Decimal.new("11667")
  end
end
