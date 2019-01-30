defmodule Explorer.Chain.BlockNumberCacheTest do
  use Explorer.DataCase

  alias Explorer.Chain.BlockNumberCache

  describe "max_number/1" do
    test "returns max number" do
      insert(:block, number: 5)

      BlockNumberCache.setup()

      assert BlockNumberCache.max_number() == 5
    end

    test "invalidates cache if period did pass" do
      insert(:block, number: 5)

      BlockNumberCache.setup(cache_period: 2_000)

      assert BlockNumberCache.max_number() == 5

      insert(:block, number: 10)

      Process.sleep(2_000)

      assert BlockNumberCache.max_number() == 10
      assert BlockNumberCache.min_number() == 5
    end

    test "does not invalidate cache if period time did not pass" do
      insert(:block, number: 5)

      BlockNumberCache.setup(cache_period: 10_000)

      assert BlockNumberCache.max_number() == 5

      insert(:block, number: 10)

      assert BlockNumberCache.max_number() == 5
    end
  end

  describe "min_number/1" do
    test "returns max number" do
      insert(:block, number: 2)

      BlockNumberCache.setup()

      assert BlockNumberCache.max_number() == 2
    end

    test "invalidates cache" do
      insert(:block, number: 5)

      BlockNumberCache.setup(cache_period: 2_000)

      assert BlockNumberCache.min_number() == 5

      insert(:block, number: 2)

      Process.sleep(2_000)

      assert BlockNumberCache.min_number() == 2
      assert BlockNumberCache.max_number() == 5
    end

    test "does not invalidate cache if period time did not pass" do
      insert(:block, number: 5)

      BlockNumberCache.setup(cache_period: 10_000)

      assert BlockNumberCache.max_number() == 5

      insert(:block, number: 2)

      assert BlockNumberCache.max_number() == 5
    end
  end
end
