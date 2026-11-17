# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Indexer.Fetcher.CoinBalance.CompactorTest do
  # not async: the tests change the application env
  use Explorer.DataCase, async: false

  alias Explorer.Chain.Address.CoinBalance
  alias Explorer.Chain.Cache.Counters.LastFetchedCounter
  alias Indexer.Fetcher.CoinBalance.Compactor

  @counter_type "coin_balances_compactor_last_block_number"

  setup do
    initial_env = Application.get_env(:indexer, Compactor)
    on_exit(fn -> Application.put_env(:indexer, Compactor, initial_env) end)

    Application.put_env(:indexer, Compactor, batch_size: 10, interval: 10, head_offset: 5)

    %{address_hash: insert(:address).hash}
  end

  defp stored_block_numbers(address_hash) do
    CoinBalance
    |> where([cb], cb.address_hash == ^address_hash)
    |> order_by([cb], asc: cb.block_number)
    |> select([cb], cb.block_number)
    |> Repo.all()
  end

  defp last_block_number do
    @counter_type |> LastFetchedCounter.get(nullable: true) |> Decimal.to_integer()
  end

  describe "compact_next_batch/0" do
    test "goes through the blocks in batches and stops at the head offset", %{address_hash: address_hash} do
      insert(:block, number: 30)

      for block_number <- [1, 2, 12, 22, 25, 26, 30] do
        insert(:fetched_balance, address_hash: address_hash, block_number: block_number, value: 100)
      end

      assert Compactor.compact_next_batch() == {:ok, {0, 9, 1}}
      assert last_block_number() == 9
      assert stored_block_numbers(address_hash) == [1, 12, 22, 25, 26, 30]

      assert Compactor.compact_next_batch() == {:ok, {10, 19, 1}}
      assert Compactor.compact_next_batch() == {:ok, {20, 25, 2}}
      assert last_block_number() == 25

      # the blocks within the head offset are left alone
      assert Compactor.compact_next_batch() == :idle
      assert stored_block_numbers(address_hash) == [1, 26, 30]
    end

    test "continues once the chain head moves on", %{address_hash: address_hash} do
      insert(:block, number: 8)
      insert(:fetched_balance, address_hash: address_hash, block_number: 1, value: 100)
      insert(:fetched_balance, address_hash: address_hash, block_number: 6, value: 100)
      insert(:fetched_balance, address_hash: address_hash, block_number: 11, value: 100)

      assert Compactor.compact_next_batch() == {:ok, {0, 3, 0}}
      assert Compactor.compact_next_batch() == :idle

      insert(:block, number: 12)

      assert Compactor.compact_next_batch() == {:ok, {4, 7, 1}}
      assert stored_block_numbers(address_hash) == [1, 11]
    end

    test "is idle on an empty chain" do
      assert Compactor.compact_next_batch() == :idle
      assert LastFetchedCounter.get(@counter_type, nullable: true) == nil
    end
  end

  describe "process" do
    test "compacts on start", %{address_hash: address_hash} do
      insert(:block, number: 30)
      insert(:fetched_balance, address_hash: address_hash, block_number: 1, value: 100)
      insert(:fetched_balance, address_hash: address_hash, block_number: 2, value: 100)
      insert(:fetched_balance, address_hash: address_hash, block_number: 29, value: 100)

      Compactor.Supervisor.Case.start_supervised!()

      wait_for_results(fn ->
        [1, 29] = stored_block_numbers(address_hash)
      end)
    end
  end
end
