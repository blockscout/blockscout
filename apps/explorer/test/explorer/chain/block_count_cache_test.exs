defmodule Explorer.Chain.BlockCountCacheTest do
  use Explorer.DataCase

  alias Explorer.Chain.BlockCountCache

  test "returns default transaction count" do
    BlockCountCache.start_link([[], [name: TestCache]])

    result = BlockCountCache.value(TestCache)

    assert is_nil(result)
  end

  test "updates cache if initial value is zero" do
    BlockCountCache.start_link([[], [name: TestCache]])

    insert(:block, consensus: true)
    insert(:block, consensus: true)
    insert(:block, consensus: false)

    _result = BlockCountCache.value(TestCache)

    Process.sleep(1000)

    updated_value = BlockCountCache.value(TestCache)

    assert updated_value == 2
  end

  test "does not update cache if cache period did not pass" do
    BlockCountCache.start_link([[], [name: TestCache]])

    insert(:block, consensus: true)
    insert(:block, consensus: true)
    insert(:block, consensus: false)

    _result = BlockCountCache.value(TestCache)

    Process.sleep(1000)

    updated_value = BlockCountCache.value(TestCache)

    assert updated_value == 2

    insert(:block, consensus: true)
    insert(:block, consensus: true)

    _updated_value = BlockCountCache.value(TestCache)

    Process.sleep(1000)

    updated_value = BlockCountCache.value(TestCache)

    assert updated_value == 2
  end
end
