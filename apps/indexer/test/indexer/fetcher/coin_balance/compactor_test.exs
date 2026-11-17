# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Indexer.Fetcher.CoinBalance.CompactorTest do
  # not async: the tests change the application env
  use Explorer.DataCase, async: false

  alias Explorer.Chain.Address.CoinBalance
  alias Explorer.Chain.Cache.Counters.LastFetchedCounter
  alias Indexer.Block.Catchup.MissingRangesCollector
  alias Indexer.Fetcher.CoinBalance.Compactor

  # Stands in for the missing ranges collector, which is not started in the tests.
  defmodule CollectorStub do
    use GenServer

    def start_link(settled_block_number) do
      GenServer.start_link(__MODULE__, settled_block_number, name: MissingRangesCollector)
    end

    @impl GenServer
    def init(settled_block_number), do: {:ok, settled_block_number}

    @impl GenServer
    def handle_call(:settled_block_number, _from, settled_block_number) do
      {:reply, settled_block_number, settled_block_number}
    end

    @impl GenServer
    def handle_call({:set, settled_block_number}, _from, _state) do
      {:reply, :ok, settled_block_number}
    end
  end

  @counter_type "coin_balances_compactor_last_block_number"

  setup do
    initial_env = Application.get_env(:indexer, Compactor)
    on_exit(fn -> Application.put_env(:indexer, Compactor, initial_env) end)

    Application.put_env(:indexer, Compactor, batch_size: 10, interval: 10, head_offset: 5)

    %{address_hash: insert(:address).hash}
  end

  defp settle_blocks_up_to(block_number) do
    case Process.whereis(MissingRangesCollector) do
      nil -> start_supervised!({CollectorStub, block_number})
      _pid -> GenServer.call(MissingRangesCollector, {:set, block_number})
    end
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
      settle_blocks_up_to(29)

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
      settle_blocks_up_to(1_000)
      insert(:fetched_balance, address_hash: address_hash, block_number: 1, value: 100)
      insert(:fetched_balance, address_hash: address_hash, block_number: 6, value: 100)
      insert(:fetched_balance, address_hash: address_hash, block_number: 11, value: 100)

      assert Compactor.compact_next_batch() == {:ok, {0, 3, 0}}
      assert Compactor.compact_next_batch() == :idle

      insert(:block, number: 12)

      assert Compactor.compact_next_batch() == {:ok, {4, 7, 1}}
      assert stored_block_numbers(address_hash) == [1, 11]
    end

    test "does not go above the settled block number", %{address_hash: address_hash} do
      insert(:block, number: 100)
      settle_blocks_up_to(12)

      for block_number <- [1, 2, 12, 13, 14, 50] do
        insert(:fetched_balance, address_hash: address_hash, block_number: block_number, value: 100)
      end

      assert Compactor.compact_next_batch() == {:ok, {0, 9, 1}}
      assert Compactor.compact_next_batch() == {:ok, {10, 12, 1}}
      assert Compactor.compact_next_batch() == :idle
      assert stored_block_numbers(address_hash) == [1, 13, 14, 50]

      settle_blocks_up_to(13)

      assert Compactor.compact_next_batch() == {:ok, {13, 13, 1}}
      assert stored_block_numbers(address_hash) == [1, 14, 50]
    end

    test "waits at a block whose coin balances are not imported yet", %{address_hash: address_hash} do
      insert(:block, number: 100)
      settle_blocks_up_to(90)

      # block 5 is stored, but the stage of its import that writes the coin balances is not finished
      block = insert(:block, number: 5)

      for block_number <- [1, 2, 6, 7, 20] do
        insert(:fetched_balance, address_hash: address_hash, block_number: block_number, value: 100)
      end

      assert Compactor.compact_next_batch() == {:ok, {0, 4, 1}}
      assert Compactor.compact_next_batch() == {:waiting, 5}
      assert Compactor.compact_next_batch() == {:waiting, 5}
      assert last_block_number() == 4
      assert stored_block_numbers(address_hash) == [1, 6, 7, 20]

      # the import finishes: the address had another balance in block 5
      insert(:fetched_balance, address_hash: block.miner_hash, block_number: 5, value: 0)
      insert(:fetched_balance, address_hash: address_hash, block_number: 5, value: 200)

      assert Compactor.compact_next_batch() == {:ok, {5, 14, 1}}
      assert stored_block_numbers(address_hash) == [1, 5, 6, 20]
    end

    test "waits at a block left without coin balances by an indexer that stopped between the import stages", %{
      address_hash: address_hash
    } do
      insert(:block, number: 100)
      settle_blocks_up_to(90)
      block = insert(:block, number: 5)

      for block_number <- [1, 6, 7, 20] do
        insert(:fetched_balance, address_hash: address_hash, block_number: block_number, value: 100)
      end

      assert Compactor.compact_next_batch() == {:ok, {0, 4, 0}}

      # nothing changes however long it takes
      for _ <- 1..3, do: assert(Compactor.compact_next_batch() == {:waiting, 5})
      assert stored_block_numbers(address_hash) == [1, 6, 7, 20]

      # the block is imported again
      insert(:fetched_balance, address_hash: block.miner_hash, block_number: 5, value: 0)

      assert Compactor.compact_next_batch() == {:ok, {5, 14, 2}}
      assert stored_block_numbers(address_hash) == [1, 20]
    end

    test "ignores non-consensus blocks without coin balances", %{address_hash: address_hash} do
      insert(:block, number: 100)
      settle_blocks_up_to(90)
      insert(:block, number: 5, consensus: false)

      for block_number <- [1, 6, 20] do
        insert(:fetched_balance, address_hash: address_hash, block_number: block_number, value: 100)
      end

      assert Compactor.compact_next_batch() == {:ok, {0, 9, 1}}
      assert stored_block_numbers(address_hash) == [1, 20]
    end

    test "is idle while it is not known which blocks are settled", %{address_hash: address_hash} do
      insert(:block, number: 30)
      insert(:fetched_balance, address_hash: address_hash, block_number: 1, value: 100)
      insert(:fetched_balance, address_hash: address_hash, block_number: 2, value: 100)
      insert(:fetched_balance, address_hash: address_hash, block_number: 29, value: 100)

      # the missing ranges collector is not running
      assert Compactor.compact_next_batch() == :idle

      # it has not scanned the whole chain yet
      settle_blocks_up_to(nil)
      assert Compactor.compact_next_batch() == :idle

      assert stored_block_numbers(address_hash) == [1, 2, 29]
      assert LastFetchedCounter.get(@counter_type, nullable: true) == nil
    end

    test "is idle on an empty chain" do
      settle_blocks_up_to(1_000)

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
      settle_blocks_up_to(29)

      Compactor.Supervisor.Case.start_supervised!()

      wait_for_results(fn ->
        [1, 29] = stored_block_numbers(address_hash)
      end)
    end
  end
end
