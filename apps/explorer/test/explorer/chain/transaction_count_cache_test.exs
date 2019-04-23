defmodule Explorer.Chain.TransactionCountCacheTest do
  use Explorer.DataCase

  alias Explorer.Chain.TransactionCountCache

  test "returns default transaction count" do
    TransactionCountCache.start_link([[], [name: TestCache]])

    result = TransactionCountCache.value(TestCache)

    assert is_nil(result)
  end

  test "updates cache if initial value is zero" do
    TransactionCountCache.start_link([[], [name: TestCache]])

    insert(:transaction)
    insert(:transaction)

    _result = TransactionCountCache.value(TestCache)

    Process.sleep(1000)

    updated_value = TransactionCountCache.value(TestCache)

    assert updated_value == 2
  end

  test "does not update cache if cache period did not pass" do
    TransactionCountCache.start_link([[], [name: TestCache]])

    insert(:transaction)
    insert(:transaction)

    _result = TransactionCountCache.value(TestCache)

    Process.sleep(1000)

    updated_value = TransactionCountCache.value(TestCache)

    assert updated_value == 2

    insert(:transaction)
    insert(:transaction)

    _updated_value = TransactionCountCache.value(TestCache)

    Process.sleep(1000)

    updated_value = TransactionCountCache.value(TestCache)

    assert updated_value == 2
  end
end
