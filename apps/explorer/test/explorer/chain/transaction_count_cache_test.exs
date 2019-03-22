defmodule Explorer.Chain.TransactionCountCacheTest do
  use Explorer.DataCase

  alias Explorer.Chain.TransactionCountCache

  test "returns default transaction count" do
    TransactionCountCache.start_link([[], []])

    result = TransactionCountCache.value()

    assert result == 0
  end

  test "updates cache if initial value is zero" do
    TransactionCountCache.start_link([[], []])

    insert(:transaction)
    insert(:transaction)

    result = TransactionCountCache.value()

    assert result == 0

    Process.sleep(500)

    updated_value = TransactionCountCache.value()

    assert updated_value == 2
  end

  test "does not update cache if cache period did not pass" do
    TransactionCountCache.start_link([[], []])

    insert(:transaction)
    insert(:transaction)

    result = TransactionCountCache.value()

    assert result == 0

    Process.sleep(500)

    updated_value = TransactionCountCache.value()

    assert updated_value == 2

    insert(:transaction)
    insert(:transaction)

    _updated_value = TransactionCountCache.value()

    Process.sleep(500)

    updated_value = TransactionCountCache.value()

    assert updated_value == 2
  end
end
