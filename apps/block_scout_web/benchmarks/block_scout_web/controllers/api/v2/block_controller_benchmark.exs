defmodule BlockScoutWeb.API.V2.BlockControllerBenchmark do
  @moduledoc """
  Benchmark for the Block API V2 controller.
  Tests the performance of the /api/v2/blocks endpoint with various data volumes.

  To run:
  ```
  cd apps/block_scout_web
  mix run benchmarks/block_scout_web/controllers/api/v2/block_controller_benchmark.exs
  ```
  """
  use BlockScoutWeb.BenchmarkCase

  alias Explorer.Repo
  alias Explorer.Chain.Block

  @doc """
  Benchmark the first page of the /api/v2/blocks endpoint. It mainly tests the performance of `Explorer.Chain.Cache.Blocks`.
  """
  def list_blocks_first_page do
    benchmark_setup()

    Benchee.run(
      %{
        "GET /api/v2/blocks first page (cached)" => fn %{conn: conn} ->
          get(conn, "/api/v2/blocks")
        end
      },
      inputs: %{
        " 0 blocks   0 transactions per block" => %{block_count: 0, transaction_per_block: 0},
        "51 blocks   0 transactions per block" => %{block_count: 51, transaction_per_block: 0},
        "51 blocks  10 transactions per block" => %{block_count: 51, transaction_per_block: 10},
        "51 blocks 100 transactions per block" => %{block_count: 51, transaction_per_block: 100},
        "51 blocks 500 transactions per block" => %{block_count: 51, transaction_per_block: 500}
      },
      before_scenario: fn %{block_count: block_count, transaction_per_block: transaction_per_block} = input ->
        reset_db()

        Application.put_env(:explorer, Explorer.Chain.Cache.Blocks, ttl_check_interval: false, global_ttl: nil)

        Supervisor.terminate_child(Explorer.Supervisor, Explorer.Chain.Cache.Blocks.child_id())
        Supervisor.restart_child(Explorer.Supervisor, Explorer.Chain.Cache.Blocks.child_id())

        0 = Repo.aggregate(Block, :count, :hash)

        block_count
        |> insert_list(:block)
        |> Enum.each(fn block ->
          transaction_per_block
          |> insert_list(:transaction)
          |> with_block(block)
        end)

        Map.put(input, :conn, get_conn())
      end,
      formatters: [Benchee.Formatters.Console],
      load: @path,
      save: [
        path: @path
      ],
      warmup: 1,
      time: 10,
      memory_time: 10
    )
  end
end

BlockScoutWeb.API.V2.BlockControllerBenchmark.list_blocks_first_page()
