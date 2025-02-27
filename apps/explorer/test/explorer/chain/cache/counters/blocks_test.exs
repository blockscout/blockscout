defmodule Explorer.Chain.Cache.Counters.BlocksTest do
  use Explorer.DataCase

  alias Explorer.Chain.Cache.Counters.BlocksCount

  setup do
    Supervisor.terminate_child(Explorer.Supervisor, BlocksCount.child_id())
    Supervisor.restart_child(Explorer.Supervisor, BlocksCount.child_id())
    :ok
  end

  test "returns default block count" do
    result = BlocksCount.get_count()

    assert is_nil(result)
  end

  test "updates cache if initial value is zero" do
    insert(:block, consensus: true)
    insert(:block, consensus: true)
    insert(:block, consensus: false)

    _result = BlocksCount.get_count()

    Process.sleep(1000)

    updated_value = BlocksCount.get_count()

    assert updated_value == 2
  end

  test "does not update cache if cache period did not pass" do
    insert(:block, consensus: true)
    insert(:block, consensus: true)
    insert(:block, consensus: false)

    _result = BlocksCount.get_count()

    Process.sleep(1000)

    updated_value = BlocksCount.get_count()

    assert updated_value == 2

    insert(:block, consensus: true)
    insert(:block, consensus: true)

    _updated_value = BlocksCount.get_count()

    Process.sleep(1000)

    updated_value = BlocksCount.get_count()

    assert updated_value == 2
  end
end
