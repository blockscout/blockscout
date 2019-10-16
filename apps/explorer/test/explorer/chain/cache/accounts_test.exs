defmodule Explorer.Chain.Cache.AccountsTest do
  use Explorer.DataCase

  alias Explorer.Chain.Cache.Accounts
  alias Explorer.Repo

  describe "drop/1" do
    test "does not drop the cache if the address fetched_coin_balance has not changed" do
      address =
        insert(:address, fetched_coin_balance: 100_000, fetched_coin_balance_block_number: 1)
        |> preload_names()

      Accounts.update(address)

      assert Accounts.take(1) == [address]

      Accounts.drop(address)

      assert Accounts.take(1) == [address]
    end

    test "drops the cache if an address was in the cache with a different fetched_coin_balance" do
      address =
        insert(:address, fetched_coin_balance: 100_000, fetched_coin_balance_block_number: 1)
        |> preload_names()

      Accounts.update(address)

      assert Accounts.take(1) == [address]

      updated_address = %{address | fetched_coin_balance: 100_001}

      Accounts.drop(updated_address)

      assert Accounts.take(1) == []
    end
  end

  defp preload_names(address) do
    Repo.preload(address, [:names])
  end
end
