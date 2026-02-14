defmodule Explorer.Chain.Metrics.Queries.IndexerMetricsTest do
  use Explorer.DataCase, async: false

  import Explorer.Factory

  alias Explorer.Chain.Metrics.Queries.IndexerMetrics

  describe "missing_blocks_count/0" do
    test "counts only within configured ranges and latest tail" do
      previous_block_ranges = Application.get_env(:indexer, :block_ranges)
      on_exit(fn -> Application.put_env(:indexer, :block_ranges, previous_block_ranges) end)

      Application.put_env(:indexer, :block_ranges, "1..3,5..latest")

      Enum.each([1, 2, 3, 5, 7, 8], fn number ->
        insert(:block, number: number, consensus: true)
      end)

      assert IndexerMetrics.missing_blocks_count() == 1
    end

    test "counts only within finite ranges" do
      previous_block_ranges = Application.get_env(:indexer, :block_ranges)
      on_exit(fn -> Application.put_env(:indexer, :block_ranges, previous_block_ranges) end)

      Application.put_env(:indexer, :block_ranges, "10..12,20..22")

      Enum.each([10, 11, 12, 20, 22], fn number ->
        insert(:block, number: number, consensus: true)
      end)

      assert IndexerMetrics.missing_blocks_count() == 1
    end
  end
end
