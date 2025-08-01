defmodule Explorer.Chain.Health.HelperTest do
  use Explorer.DataCase
  alias Explorer.Chain.Health.Helper, as: HealthHelper
  alias Explorer.Chain.Cache.Blocks

  setup do
    Supervisor.terminate_child(Explorer.Supervisor, Blocks.child_id())
    Supervisor.restart_child(Explorer.Supervisor, Blocks.child_id())

    :ok
  end

  describe "last_cache_block/0" do
    test "returns {block_number, block_timestamp}" do
      block = insert(:block, consensus: true)

      Blocks.update(block)

      assert {block.number, block.timestamp} == HealthHelper.last_cache_block()
    end

    test "return nil, if no blocks in the DB" do
      assert nil == HealthHelper.last_cache_block()
    end
  end

  describe "last_db_block_status/0" do
    test "return no_blocks errors if db is empty" do
      assert {:error, :no_blocks} = HealthHelper.last_db_block_status()
    end

    test "returns {:ok, last_block_period} if block is in healthy period" do
      insert(:block, consensus: true)

      assert {:ok, _, _} = HealthHelper.last_db_block_status()
    end

    test "return {:stale, _, _} if block is not in healthy period" do
      insert(:block, consensus: true, timestamp: Timex.shift(DateTime.utc_now(), hours: -50))

      assert {:stale, _, _} = HealthHelper.last_db_block_status()
    end
  end
end
