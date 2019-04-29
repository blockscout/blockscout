defmodule Explorer.Chain.BlockCountCacheTest do
  use Explorer.DataCase

  alias Explorer.Chain.BlockCountCache

  describe "count/0" do
    test "return count" do
      insert(:block, number: 1, consensus: true)
      insert(:block, number: 2, consensus: true)
      insert(:block, number: 3, consensus: false)

      BlockCountCache.setup()

      assert BlockCountCache.count() == 2
    end

    test "invalidates cache if period did pass" do
      insert(:block, number: 1, consensus: true)

      Application.put_env(:explorer, BlockCountCache, ttl: 2_00)
      BlockCountCache.setup()

      assert BlockCountCache.count() == 1

      insert(:block, number: 2, consensus: true)

      Process.sleep(2_000)

      assert BlockCountCache.count() == 2
    end

    test "does not invalidate cache if period time did not pass" do
      insert(:block, number: 1, consensus: true)

      Application.put_env(:explorer, BlockCountCache, ttl: 2_00)
      BlockCountCache.setup()

      assert BlockCountCache.count() == 1

      insert(:block, number: 2, consensus: true)

      assert BlockCountCache.count() == 1
    end
  end
end
