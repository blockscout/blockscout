# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Chain.Cache.Counters.AddressesAggregatesTest do
  use Explorer.DataCase

  alias Explorer.Chain.Cache.Counters.{AddressesAggregates, LastFetchedCounter}

  @burn_address_hash "0x0000000000000000000000000000000000000000"

  setup do
    Supervisor.terminate_child(Explorer.Supervisor, AddressesAggregates.child_id())
    Supervisor.restart_child(Explorer.Supervisor, AddressesAggregates.child_id())
    :ok
  end

  describe "fetch_aggregates/0" do
    test "computes count, sum and sum minus burnt with a single query" do
      insert(:address, fetched_coin_balance: 0)
      insert(:address, fetched_coin_balance: nil)
      insert(:address, fetched_coin_balance: 1)
      insert(:address, fetched_coin_balance: 2)
      insert(:address, fetched_coin_balance: 3)
      insert(:address, hash: @burn_address_hash, fetched_coin_balance: 4)

      assert %{count: 6, sum: sum, sum_minus_burnt: sum_minus_burnt} = AddressesAggregates.fetch_aggregates()
      assert Decimal.equal?(sum, 10)
      assert Decimal.equal?(sum_minus_burnt, 6)
    end

    test "returns zeros on empty table" do
      assert %{count: 0, sum: sum, sum_minus_burnt: sum_minus_burnt} = AddressesAggregates.fetch_aggregates()
      assert Decimal.equal?(sum, 0)
      assert Decimal.equal?(sum_minus_burnt, 0)
    end
  end

  describe "consolidate/0" do
    test "populates the cache and persists the last fetched counters" do
      insert(:address, fetched_coin_balance: 1)
      insert(:address, fetched_coin_balance: 2)
      insert(:address, hash: @burn_address_hash, fetched_coin_balance: 4)

      AddressesAggregates.consolidate()

      assert AddressesAggregates.get_addresses_count() == 3
      assert Decimal.equal?(AddressesAggregates.get_sum(), 7)
      assert Decimal.equal?(AddressesAggregates.get_sum_minus_burnt(), 3)

      assert Decimal.equal?(LastFetchedCounter.get("addresses_count"), 3)
      assert Decimal.equal?(LastFetchedCounter.get("addresses_coin_balance_sum"), 7)
      assert Decimal.equal?(LastFetchedCounter.get("addresses_coin_balance_sum_minus_burnt"), 3)
    end
  end

  describe "fallbacks" do
    test "returns 0 for the sums and the count when nothing is cached nor persisted" do
      assert Decimal.equal?(AddressesAggregates.get_sum(), 0)
      assert Decimal.equal?(AddressesAggregates.get_sum_minus_burnt(), 0)
      assert AddressesAggregates.get_addresses_count() == 0

      wait_for_async_task()
    end

    test "returns the last persisted values when the cache is empty" do
      LastFetchedCounter.upsert(%{counter_type: "addresses_count", value: Decimal.new(5)})
      LastFetchedCounter.upsert(%{counter_type: "addresses_coin_balance_sum", value: Decimal.new(42)})
      LastFetchedCounter.upsert(%{counter_type: "addresses_coin_balance_sum_minus_burnt", value: Decimal.new(41)})

      assert AddressesAggregates.get_addresses_count() == 5
      assert Decimal.equal?(AddressesAggregates.get_sum(), 42)
      assert Decimal.equal?(AddressesAggregates.get_sum_minus_burnt(), 41)

      wait_for_async_task()
    end

    test "launches a single async refresh which updates all the values" do
      insert(:address, fetched_coin_balance: 1)
      insert(:address, fetched_coin_balance: 2)
      insert(:address, fetched_coin_balance: 3)
      insert(:address, hash: @burn_address_hash, fetched_coin_balance: 4)

      _ = AddressesAggregates.get_sum()

      Process.sleep(1000)

      assert AddressesAggregates.get_addresses_count() == 4
      assert Decimal.equal?(AddressesAggregates.get_sum(), 10)
      assert Decimal.equal?(AddressesAggregates.get_sum_minus_burnt(), 6)
    end

    test "does not update cache if cache period did not pass" do
      insert(:address, fetched_coin_balance: 1)
      insert(:address, fetched_coin_balance: 2)
      insert(:address, fetched_coin_balance: 3)

      _ = AddressesAggregates.get_sum()

      Process.sleep(1000)

      assert Decimal.equal?(AddressesAggregates.get_sum(), 6)
      assert AddressesAggregates.get_addresses_count() == 3

      insert(:address, fetched_coin_balance: 4)
      insert(:address, fetched_coin_balance: 5)

      _ = AddressesAggregates.get_sum()

      Process.sleep(1000)

      assert Decimal.equal?(AddressesAggregates.get_sum(), 6)
      assert AddressesAggregates.get_addresses_count() == 3
    end
  end

  # Lets the refresh task launched by a fallback finish before the test's DB
  # connection is checked in, instead of killing it mid-query.
  defp wait_for_async_task do
    case ConCache.get(AddressesAggregates.cache_name(), :async_task) do
      pid when is_pid(pid) ->
        ref = Process.monitor(pid)
        assert_receive {:DOWN, ^ref, :process, ^pid, _}, :timer.seconds(5)

      _ ->
        :ok
    end
  end
end
