defmodule Explorer.ChainTest do
  use Explorer.DataCase

  alias Explorer.Chain
  alias Timex.Duration

  describe "fetch/0" do
    test "returns -1 for the number when there are no blocks" do
      chain = Chain.fetch()
      assert chain.number == -1
    end

    test "returns the highest block number when there is a block" do
      insert(:block, number: 1)
      insert(:block, number: 100)
      chain = Chain.fetch()
      assert chain.number == 100
    end

    test "returns the latest block timestamp" do
      time = DateTime.utc_now()
      insert(:block, timestamp: time)
      chain = Chain.fetch()
      assert Timex.diff(chain.timestamp, time, :seconds) == 0
    end

    test "returns the average time between blocks" do
      time = DateTime.utc_now()
      next_time = Timex.shift(time, seconds: 5)
      insert(:block, timestamp: time)
      insert(:block, timestamp: next_time)
      chain = Chain.fetch()
      assert chain.average_time == %Duration{
        seconds: 5,
        megaseconds: 0,
        microseconds: 0
      }
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
      chain = Chain.fetch()
      assert chain.transaction_count == 1
    end

    test "returns the number of skipped blocks" do
      insert(:block, %{number: 0})
      insert(:block, %{number: 2})
      chain = Chain.fetch()
      assert chain.skipped_blocks == 1
    end

    test "returns the lag between validation and insertion time" do
      validation_time = DateTime.utc_now()
      inserted_at = validation_time |> Timex.shift(seconds: 5)
      insert(:block, timestamp: validation_time, inserted_at: inserted_at)
      chain = Chain.fetch()
      assert chain.lag == %Duration{seconds: 5, megaseconds: 0, microseconds: 0}
    end

    test "returns the number of blocks inserted in the last minute" do
      old_inserted_at = Timex.shift(DateTime.utc_now(), days: -1)
      insert(:block, inserted_at: old_inserted_at)
      insert(:block)
      chain = Chain.fetch()
      assert chain.block_velocity == 1
    end

    test "returns the number of transactions inserted in the last minute" do
      old_inserted_at = Timex.shift(DateTime.utc_now(), days: -1)
      insert(:transaction, inserted_at: old_inserted_at)
      insert(:transaction)
      chain = Chain.fetch()
      assert chain.transaction_velocity == 1
    end

    test "returns the last five blocks" do
      insert_list(6, :block)
      chain = Chain.fetch()
      assert chain.blocks |> Enum.count() == 5
    end

    test "returns the last five transactions with blocks" do
      block = insert(:block)
      insert_list(6, :transaction)
      |> Enum.map(fn (transaction) ->
        insert(:block_transaction, block: block, transaction: transaction)
      end)
      chain = Chain.fetch()
      assert chain.transactions |> Enum.count() == 5
    end
  end
end
