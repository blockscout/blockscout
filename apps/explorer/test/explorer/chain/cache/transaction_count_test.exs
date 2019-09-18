defmodule Explorer.Chain.Cache.TransactionCountTest do
  use Explorer.DataCase

  alias Explorer.Chain.Cache.TransactionCount

  setup do
    Supervisor.terminate_child(Explorer.Supervisor, TransactionCount.child_id())
    Supervisor.restart_child(Explorer.Supervisor, TransactionCount.child_id())
    :ok
  end

  test "returns default transaction count" do
    result = TransactionCount.get_count()

    assert is_nil(result)
  end

  test "updates cache if initial value is zero" do
    insert(:transaction)
    insert(:transaction)

    _result = TransactionCount.get_count()

    Process.sleep(1000)

    updated_value = TransactionCount.get_count()

    assert updated_value == 2
  end

  test "does not update cache if cache period did not pass" do
    insert(:transaction)
    insert(:transaction)

    _result = TransactionCount.get_count()

    Process.sleep(1000)

    updated_value = TransactionCount.get_count()

    assert updated_value == 2

    insert(:transaction)
    insert(:transaction)

    _updated_value = TransactionCount.get_count()

    Process.sleep(1000)

    updated_value = TransactionCount.get_count()

    assert updated_value == 2
  end
end
