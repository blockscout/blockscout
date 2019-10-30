defmodule Explorer.Chain.Cache.AddressCountTest do
  use Explorer.DataCase

  alias Explorer.Chain.Cache.AddressCount

  setup do
    Supervisor.terminate_child(Explorer.Supervisor, AddressCount.child_id())
    Supervisor.restart_child(Explorer.Supervisor, AddressCount.child_id())
    :ok
  end

  test "returns default address count" do
    result = AddressCount.get_count()

    assert is_nil(result)
  end

  test "updates cache if initial value is zero" do
    insert(:address)
    insert(:address)

    _result = AddressCount.get_count()

    Process.sleep(1000)

    updated_value = AddressCount.get_count()

    assert updated_value == 2
  end

  test "does not update cache if cache period did not pass" do
    insert(:address)
    insert(:address)

    _result = AddressCount.get_count()

    Process.sleep(1000)

    updated_value = AddressCount.get_count()

    assert updated_value == 2

    insert(:address)
    insert(:address)

    _updated_value = AddressCount.get_count()

    Process.sleep(1000)

    updated_value = AddressCount.get_count()

    assert updated_value == 2
  end
end
