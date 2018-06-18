defmodule Explorer.Indexer.AddressBalanceFetcherTest do
  # MUST be `async: false` so that {:shared, pid} is set for connection to allow AddressBalanceFetcher's self-send to have
  # connection allowed immediately.
  use Explorer.DataCase, async: false

  alias Explorer.Chain.{Address, Hash, Wei}
  alias Explorer.Indexer.{AddressBalanceFetcher, AddressBalanceFetcherCase}

  @block_number 2_932_838
  @hash %Explorer.Chain.Hash{
    byte_count: 20,
    bytes: <<139, 243, 141, 71, 100, 146, 144, 100, 242, 212, 211, 165, 101, 32, 167, 106, 179, 223, 65, 91>>
  }

  setup do
    start_supervised!({Task.Supervisor, name: Explorer.Indexer.TaskSupervisor})

    :ok
  end

  describe "init/1" do
    test "fetches unfetched Block miner balance" do
      {:ok, miner_hash} = Hash.Truncated.cast("0xe8ddc5c7a2d2f0d7a9798459c0104fdf5e987aca")
      miner = insert(:address, hash: miner_hash)
      block = insert(:block, miner: miner, number: 34)

      assert miner.fetched_balance == nil
      assert miner.fetched_balance_block_number == nil

      AddressBalanceFetcherCase.start_supervised!()

      fetched_address =
        wait(fn ->
          Repo.one!(
            from(address in Address, where: address.hash == ^miner_hash and not is_nil(address.fetched_balance))
          )
        end)

      assert fetched_address.fetched_balance == %Wei{value: Decimal.new(252_460_834_000_000_000_000_000_000)}
      assert fetched_address.fetched_balance_block_number == block.number
    end

    test "fetches unfetched addresses when less than max batch size" do
      {:ok, miner_hash} = Hash.Truncated.cast("0xe8ddc5c7a2d2f0d7a9798459c0104fdf5e987aca")
      miner = insert(:address, hash: miner_hash)
      block = insert(:block, miner: miner, number: 34)

      AddressBalanceFetcherCase.start_supervised!(max_batch_size: 2)

      fetched_address =
        wait(fn ->
          Repo.one!(
            from(address in Address, where: address.hash == ^miner_hash and not is_nil(address.fetched_balance))
          )
        end)

      assert fetched_address.fetched_balance == %Wei{value: Decimal.new(252_460_834_000_000_000_000_000_000)}
      assert fetched_address.fetched_balance_block_number == block.number
    end
  end

  describe "async_fetch_balances/1" do
    test "fetches balances for address_hashes" do
      AddressBalanceFetcherCase.start_supervised!()

      assert :ok = AddressBalanceFetcher.async_fetch_balances([%{block_number: @block_number, hash: @hash}])

      address =
        wait(fn ->
          Repo.get!(Address, @hash)
        end)

      assert address.fetched_balance == %Wei{value: Decimal.new(1)}
      assert address.fetched_balance_block_number == @block_number
    end
  end

  defp wait(producer) do
    producer.()
  rescue
    Ecto.NoResultsError ->
      Process.sleep(100)
      wait(producer)
  end
end
