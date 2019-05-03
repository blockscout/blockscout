defmodule Explorer.Chain.BlockCountCacheTest do
  use Explorer.DataCase

  alias Explorer.Chain.BlockCountCache

  describe "count/0" do
    test "return count" do
      Application.put_env(:explorer, BlockCountCache, ttl: 200)
      BlockCountCache.start_link(name: BlockTest)
      Process.sleep(300)

      insert(:block, number: 1, consensus: true)
      insert(:block, number: 2, consensus: true)
      insert(:block, number: 3, consensus: false)

      _result = BlockCountCache.count(BlockTest)

      Process.sleep(300)

      assert BlockCountCache.count(BlockTest) == 2
    end

    test "invalidates cache if period did pass" do
      Application.put_env(:explorer, BlockCountCache, ttl: 200)
      BlockCountCache.start_link(name: BlockTest)
      Process.sleep(300)

      insert(:block, number: 1, consensus: true)

      _result = BlockCountCache.count(BlockTest)

      Process.sleep(300)
      assert BlockCountCache.count(BlockTest) == 1

      insert(:block, number: 2, consensus: true)
      Process.sleep(300)

      assert BlockCountCache.count(BlockTest) == 2
    end

    test "does not invalidate cache if period time did not pass" do
      Application.put_env(:explorer, BlockCountCache, ttl: 200)
      BlockCountCache.start_link(name: BlockTest)
      Process.sleep(300)

      insert(:block, number: 1, consensus: true)

      _result = BlockCountCache.count(BlockTest)
      Process.sleep(300)

      assert BlockCountCache.count(BlockTest) == 1

      insert(:block, number: 2, consensus: true)

      assert BlockCountCache.count(BlockTest) == 1
    end
  end
end
