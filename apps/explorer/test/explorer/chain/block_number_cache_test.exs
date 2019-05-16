defmodule Explorer.Chain.BlockNumberCacheTest do
  use Explorer.DataCase

  alias Explorer.Chain.BlockNumberCache

  setup do
    Application.put_env(:explorer, Explorer.Chain.BlockNumberCache, enabled: true)

    on_exit(fn ->
      Application.put_env(:explorer, Explorer.Chain.BlockNumberCache, enabled: false)
    end)
  end

  describe "max_number/1" do
    test "returns max number" do
      insert(:block, number: 5)

      BlockNumberCache.setup()

      assert BlockNumberCache.max_number() == 5
    end
  end

  describe "min_number/1" do
    test "returns max number" do
      insert(:block, number: 2)

      BlockNumberCache.setup()

      assert BlockNumberCache.max_number() == 2
    end
  end

  describe "update/1" do
    test "updates max number" do
      insert(:block, number: 2)

      BlockNumberCache.setup()

      assert BlockNumberCache.max_number() == 2

      assert BlockNumberCache.update(3)

      assert BlockNumberCache.max_number() == 3
    end

    test "updates min number" do
      insert(:block, number: 2)

      BlockNumberCache.setup()

      assert BlockNumberCache.min_number() == 2

      assert BlockNumberCache.update(1)

      assert BlockNumberCache.min_number() == 1
    end
  end
end
