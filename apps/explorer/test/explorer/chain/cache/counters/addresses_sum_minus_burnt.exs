defmodule Explorer.Chain.Cache.Counters.AddressesCoinBalanceSumMinusBurntTest do
  use Explorer.DataCase

  alias Explorer.Chain.Cache.Counters.AddressesCoinBalanceSumMinusBurnt

  setup do
    Supervisor.terminate_child(Explorer.Supervisor, AddressesCoinBalanceSumMinusBurnt.child_id())
    Supervisor.restart_child(Explorer.Supervisor, AddressesCoinBalanceSumMinusBurnt.child_id())
    :ok
  end

  test "returns default address sum" do
    result = AddressesCoinBalanceSumMinusBurnt.get_sum_minus_burnt()

    assert result == Decimal.new(0)
  end

  test "updates cache if initial value is zero" do
    insert(:address, fetched_coin_balance: 1)
    insert(:address, fetched_coin_balance: 2)
    insert(:address, fetched_coin_balance: 3)
    insert(:address, hash: "0x0000000000000000000000000000000000000000", fetched_coin_balance: 4)

    _result = AddressesCoinBalanceSumMinusBurnt.get_sum_minus_burnt()

    Process.sleep(1000)

    updated_value = Decimal.to_integer(AddressesCoinBalanceSumMinusBurnt.get_sum_minus_burnt())

    assert updated_value == 6
  end

  test "does not update cache if cache period did not pass" do
    insert(:address, fetched_coin_balance: 1)
    insert(:address, fetched_coin_balance: 2)
    insert(:address, fetched_coin_balance: 3)
    insert(:address, hash: "0x0000000000000000000000000000000000000000", fetched_coin_balance: 4)

    _result = AddressesCoinBalanceSumMinusBurnt.get_sum_minus_burnt()

    Process.sleep(1000)

    updated_value = Decimal.to_integer(AddressesCoinBalanceSumMinusBurnt.get_sum_minus_burnt())

    assert updated_value == 6

    insert(:address, fetched_coin_balance: 4)
    insert(:address, fetched_coin_balance: 5)

    _updated_value = AddressesCoinBalanceSumMinusBurnt.get_sum_minus_burnt()

    Process.sleep(1000)

    updated_value = Decimal.to_integer(AddressesCoinBalanceSumMinusBurnt.get_sum_minus_burnt())

    assert updated_value == 6
  end
end
