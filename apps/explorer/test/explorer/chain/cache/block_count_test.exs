defmodule Explorer.Chain.Cache.BlockCountTest do
  use Explorer.DataCase

  alias Explorer.Chain.Cache.BlockCount

  test "returns default transaction count" do
    BlockCount.start_link(name: BlockTestCache)

    result = BlockCount.count(BlockTestCache)

    assert is_nil(result)
  end

  test "updates cache if initial value is zero" do
    BlockCount.start_link(name: BlockTestCache)

    insert(:block, consensus: true)
    insert(:block, consensus: true)
    insert(:block, consensus: false)

    _result = BlockCount.count(BlockTestCache)

    Process.sleep(1000)

    updated_value = BlockCount.count(BlockTestCache)

    assert updated_value == 2
  end

  test "does not update cache if cache period did not pass" do
    BlockCount.start_link(name: BlockTestCache)

    insert(:block, consensus: true)
    insert(:block, consensus: true)
    insert(:block, consensus: false)

    _result = BlockCount.count(BlockTestCache)

    Process.sleep(1000)

    updated_value = BlockCount.count(BlockTestCache)

    assert updated_value == 2

    insert(:block, consensus: true)
    insert(:block, consensus: true)

    _updated_value = BlockCount.count(BlockTestCache)

    Process.sleep(1000)

    updated_value = BlockCount.count(BlockTestCache)

    assert updated_value == 2
  end
end
