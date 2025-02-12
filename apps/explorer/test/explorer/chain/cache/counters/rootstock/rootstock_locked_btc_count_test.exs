defmodule Explorer.Chain.Cache.Counters.Rootstock.LockedBTCCountTest do
  use Explorer.DataCase

  alias Explorer.Chain.Cache.Counters.Rootstock.LockedBTCCount
  alias Explorer.Chain.{Transaction, Wei}

  @bridge_address "0x0000000000000000000000000000000001000006"

  setup do
    transaction_configuration = Application.get_env(:explorer, Transaction)
    Application.put_env(:explorer, Transaction, rootstock_bridge_address: @bridge_address)

    :ok

    Supervisor.terminate_child(Explorer.Supervisor, LockedBTCCount.child_id())
    Supervisor.restart_child(Explorer.Supervisor, LockedBTCCount.child_id())

    on_exit(fn ->
      Application.put_env(:explorer, Transaction, transaction_configuration)
    end)

    :ok
  end

  test "returns nil in case if there is no bridged address in the database" do
    result = LockedBTCCount.get_locked_value()

    assert is_nil(result)
  end

  test "updates cache if initial value is zero and returns converted wei" do
    insert(:address, hash: @bridge_address, fetched_coin_balance: 42_000_000_000_000_000_000)

    result = LockedBTCCount.get_locked_value()

    assert result == Wei.from(Decimal.new(21_000_000), :ether) |> Wei.sub(Wei.from(Decimal.new(42), :ether))
  end
end
