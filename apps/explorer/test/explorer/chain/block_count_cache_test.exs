defmodule Explorer.Chain.BlockCountCacheTest do
  use Explorer.DataCase

  alias Explorer.Chain.BlockCountCache

  test "returns default transaction count" do
    BlockCountCache.start_link(name: BlockTestCache)

    result = BlockCountCache.count(BlockTestCache)

    assert is_nil(result)
  end

  test "updates cache if initial value is zero" do
    BlockCountCache.start_link(name: BlockTestCache)

    insert(:block, consensus: true)
    insert(:block, consensus: true)
    insert(:block, consensus: false)

    _result = BlockCountCache.count(BlockTestCache)

    Process.sleep(1000)

    updated_value = BlockCountCache.count(BlockTestCache)

    assert updated_value == 2
  end

  test "does not update cache if cache period did not pass" do
    BlockCountCache.start_link(name: BlockTestCache)

    insert(:block, consensus: true)
    insert(:block, consensus: true)
    insert(:block, consensus: false)

    _result = BlockCountCache.count(BlockTestCache)

    Process.sleep(1000)

    updated_value = BlockCountCache.count(BlockTestCache)

    assert updated_value == 2

    insert(:block, consensus: true)
    insert(:block, consensus: true)

    _updated_value = BlockCountCache.count(BlockTestCache)

    Process.sleep(1000)

    updated_value = BlockCountCache.count(BlockTestCache)

    assert updated_value == 2
  end
end
