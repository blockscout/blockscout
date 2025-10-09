defmodule Explorer.Chain.Cache.Counters.TransactionsTest do
  use Explorer.DataCase
  alias Explorer.Chain.Cache.Counters.TransactionsCount

  setup do
    Supervisor.terminate_child(Explorer.Supervisor, TransactionsCount.child_id())
    Supervisor.restart_child(Explorer.Supervisor, TransactionsCount.child_id())
    on_exit(fn -> Supervisor.terminate_child(Explorer.Supervisor, TransactionsCount.child_id()) end)
    :ok
  end

  test "returns default transaction count" do
    result = TransactionsCount.get_count()

    assert is_nil(result)
  end

  test "updates cache if initial value is zero" do
    insert(:transaction)
    insert(:transaction)

    _result = TransactionsCount.get_count()

    Process.sleep(1000)

    updated_value = TransactionsCount.get_count()

    assert updated_value == 2
  end

  test "does not update cache if cache period did not pass" do
    insert(:transaction)
    insert(:transaction)

    _result = TransactionsCount.get_count()

    Process.sleep(1000)

    updated_value = TransactionsCount.get_count()

    assert updated_value == 2

    insert(:transaction)
    insert(:transaction)

    _updated_value = TransactionsCount.get_count()

    Process.sleep(1000)

    updated_value = TransactionsCount.get_count()

    assert updated_value == 2
  end

  test "returns 0 on empty table" do
    assert 0 == TransactionsCount.get()
  end
end
