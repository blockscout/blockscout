defmodule Explorer.Chain.StatisticsTest do
  use Explorer.DataCase

  alias Explorer.Chain.Statistics
  alias Timex.Duration

  describe "fetch/0" do
    test "returns -1 for the number when there are no blocks" do
      assert %Statistics{number: -1} = Statistics.fetch()
    end

    test "returns the highest block number when there is a block" do
      insert(:block, number: 1)

      max_number = 100
      insert(:block, number: max_number)

      assert %Statistics{number: ^max_number} = Statistics.fetch()
    end

    test "returns the latest block timestamp" do
      time = DateTime.utc_now()
      insert(:block, timestamp: time)

      statistics = Statistics.fetch()

      assert Timex.diff(statistics.timestamp, time, :seconds) == 0
    end

    test "returns the average time between blocks" do
      time = DateTime.utc_now()
      next_time = Timex.shift(time, seconds: 5)
      insert(:block, timestamp: time)
      insert(:block, timestamp: next_time)

      assert %Statistics{
               average_time: %Duration{
                 seconds: 5,
                 megaseconds: 0,
                 microseconds: 0
               }
             } = Statistics.fetch()
    end

    test "returns the count of transactions from blocks in the last day" do
      time = DateTime.utc_now()
      last_week = Timex.shift(time, days: -8)
      block = insert(:block, timestamp: time)
      old_block = insert(:block, timestamp: last_week)
      transaction = insert(:transaction)
      old_transaction = insert(:transaction)
      insert(:block_transaction, block: block, transaction: transaction)
      insert(:block_transaction, block: old_block, transaction: old_transaction)

      assert %Statistics{transaction_count: 1} = Statistics.fetch()
    end

    test "returns the number of skipped blocks" do
      insert(:block, %{number: 0})
      insert(:block, %{number: 2})

      statistics = Statistics.fetch()

      assert statistics.skipped_blocks == 1
    end

    test "returns the lag between validation and insertion time" do
      validation_time = DateTime.utc_now()
      inserted_at = validation_time |> Timex.shift(seconds: 5)
      insert(:block, timestamp: validation_time, inserted_at: inserted_at)

      assert %Statistics{lag: %Duration{seconds: 5, megaseconds: 0, microseconds: 0}} =
               Statistics.fetch()
    end

    test "returns the number of blocks inserted in the last minute" do
      old_inserted_at = Timex.shift(DateTime.utc_now(), days: -1)
      insert(:block, inserted_at: old_inserted_at)
      insert(:block)

      statistics = Statistics.fetch()

      assert statistics.block_velocity == 1
    end

    test "returns the number of transactions inserted in the last minute" do
      old_inserted_at = Timex.shift(DateTime.utc_now(), days: -1)
      insert(:transaction, inserted_at: old_inserted_at)
      insert(:transaction)

      assert %Statistics{transaction_velocity: 1} = Statistics.fetch()
    end

    test "returns the last five blocks" do
      insert_list(6, :block)

      statistics = Statistics.fetch()

      assert statistics.blocks |> Enum.count() == 5
    end

    test "returns the last five transactions with blocks" do
      block = insert(:block)

      6
      |> insert_list(:transaction)
      |> Enum.map(fn transaction ->
        insert(:block_transaction, block: block, transaction: transaction)
      end)

      statistics = Statistics.fetch()

      assert statistics.transactions |> Enum.count() == 5
    end
  end
end
