defmodule Explorer.Chain.Cache.TransactionCountTest do
  use Explorer.DataCase

  alias Explorer.Chain.Cache.TransactionCount

  test "returns default transaction count" do
    TransactionCount.start_link([[], [name: TestCache]])

    result = TransactionCount.value(TestCache)

    assert is_nil(result)
  end

  test "updates cache if initial value is zero" do
    TransactionCount.start_link([[], [name: TestCache]])

    insert(:transaction)
    insert(:transaction)

    _result = TransactionCount.value(TestCache)

    Process.sleep(1000)

    updated_value = TransactionCount.value(TestCache)

    assert updated_value == 2
  end

  test "does not update cache if cache period did not pass" do
    TransactionCount.start_link([[], [name: TestCache]])

    insert(:transaction)
    insert(:transaction)

    _result = TransactionCount.value(TestCache)

    Process.sleep(1000)

    updated_value = TransactionCount.value(TestCache)

    assert updated_value == 2

    insert(:transaction)
    insert(:transaction)

    _updated_value = TransactionCount.value(TestCache)

    Process.sleep(1000)

    updated_value = TransactionCount.value(TestCache)

    assert updated_value == 2
  end
end
