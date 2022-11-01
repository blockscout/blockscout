path = "benchmarks/explorer/chain/recent_collated_transactions.benchee"

import Explorer.Factory

alias Explorer.{Chain, Repo}
alias Explorer.Chain.Block

Benchee.run(
  %{
    "Explorer.Chain.recent_collated_transactions" => fn _ ->
      Chain.recent_collated_transactions(true)
    end
  },
  inputs: %{
    "   0 blocks   0 transactions per block" => %{block_count: 0, transaction_count_per_block: 0},
    "  10 blocks   0 transactions per block" => %{block_count: 10, transaction_count_per_block: 0},
    "  10 blocks   1 transaction per block" => %{block_count: 10, transaction_count_per_block: 1},
    "  10 blocks  10 transactions per blocks" => %{block_count: 10, transaction_count_per_block: 10},
    "  10 blocks 100 transactions per blocks" => %{block_count: 10, transaction_count_per_block: 100},
    "  10 blocks 250 transactions per blocks" => %{block_count: 10, transaction_count_per_block: 250},
    " 100 blocks   0 transactions per block" => %{block_count: 100, transaction_count_per_block: 0},
    " 100 blocks   1 transaction per block" => %{block_count: 100, transaction_count_per_block: 1},
    " 100 blocks  10 transactions per blocks" => %{block_count: 100, transaction_count_per_block: 10},
    " 100 blocks 100 transactions per blocks" => %{block_count: 100, transaction_count_per_block: 100},
    " 100 blocks 250 transactions per blocks" => %{block_count: 100, transaction_count_per_block: 250},
    "1000 blocks   0 transactions per block" => %{block_count: 1000, transaction_count_per_block: 0},
    "1000 blocks   1 transaction per block" => %{block_count: 1000, transaction_count_per_block: 1},
    "1000 blocks  10 transactions per blocks" => %{block_count: 1000, transaction_count_per_block: 10},
    "1000 blocks 100 transactions per blocks" => %{block_count: 1000, transaction_count_per_block: 100}
  },
  before_scenario: fn %{block_count: block_count, transaction_count_per_block: transaction_count_per_block} = input ->
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo, ownership_timeout: :infinity)

    # ensure database is clean from failed runs
    0 = Repo.aggregate(Block, :count, :hash)

    block_count
    |> insert_list(:block)
    |> Enum.each(fn block ->
      transaction_count_per_block
      |> insert_list(:transaction)
      |> with_block(block)
    end)

    input
  end,
  formatter_options: %{
    console: %{extended_statistics: true}
  },
  load: path,
  save: [
    path: path,
    tag: "transactions-block-number"
  ],
  time: 10
)
