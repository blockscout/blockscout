# SPDX-License-Identifier: LicenseRef-Blockscout
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

  describe "with consolidation disabled" do
    setup do
      initial_config = Application.get_env(:explorer, TransactionsCount)
      Application.put_env(:explorer, TransactionsCount, Keyword.put(initial_config, :enable_consolidation, false))
      on_exit(fn -> Application.put_env(:explorer, TransactionsCount, initial_config) end)
      :ok
    end

    test "get/0 does not start the counting task and does not populate the cache" do
      insert(:transaction)
      insert(:transaction)

      result = TransactionsCount.get()

      assert is_integer(result)

      Process.sleep(1000)

      assert %{count: nil, async_task: nil} == TransactionsCount.current_values([:count, :async_task])
    end

    test "get_count/0 fallback does not start the counting task" do
      insert(:transaction)

      assert is_nil(TransactionsCount.get_count())

      Process.sleep(1000)

      assert %{count: nil, async_task: nil} == TransactionsCount.current_values([:count, :async_task])
    end
  end
end
