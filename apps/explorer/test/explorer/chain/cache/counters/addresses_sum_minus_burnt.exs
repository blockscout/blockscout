defmodule Explorer.Chain.Cache.Counters.AddressesSumMinusBurntTest do
  use Explorer.DataCase

  alias Explorer.Chain.Cache.Counters.AddressesSumMinusBurnt

  setup do
    Supervisor.terminate_child(Explorer.Supervisor, AddressesSumMinusBurnt.child_id())
    Supervisor.restart_child(Explorer.Supervisor, AddressesSumMinusBurnt.child_id())
    :ok
  end

  test "returns default address sum" do
    result = AddressesSumMinusBurnt.get_sum_minus_burnt()

    assert result == Decimal.new(0)
  end

  test "updates cache if initial value is zero" do
    insert(:address, fetched_coin_balance: 1)
    insert(:address, fetched_coin_balance: 2)
    insert(:address, fetched_coin_balance: 3)
    insert(:address, hash: "0x0000000000000000000000000000000000000000", fetched_coin_balance: 4)

    _result = AddressesSumMinusBurnt.get_sum_minus_burnt()

    Process.sleep(1000)

    updated_value = Decimal.to_integer(AddressesSumMinusBurnt.get_sum_minus_burnt())

    assert updated_value == 6
  end

  test "does not update cache if cache period did not pass" do
    insert(:address, fetched_coin_balance: 1)
    insert(:address, fetched_coin_balance: 2)
    insert(:address, fetched_coin_balance: 3)
    insert(:address, hash: "0x0000000000000000000000000000000000000000", fetched_coin_balance: 4)

    _result = AddressesSumMinusBurnt.get_sum_minus_burnt()

    Process.sleep(1000)

    updated_value = Decimal.to_integer(AddressesSumMinusBurnt.get_sum_minus_burnt())

    assert updated_value == 6

    insert(:address, fetched_coin_balance: 4)
    insert(:address, fetched_coin_balance: 5)

    _updated_value = AddressesSumMinusBurnt.get_sum_minus_burnt()

    Process.sleep(1000)

    updated_value = Decimal.to_integer(AddressesSumMinusBurnt.get_sum_minus_burnt())

    assert updated_value == 6
  end
end
