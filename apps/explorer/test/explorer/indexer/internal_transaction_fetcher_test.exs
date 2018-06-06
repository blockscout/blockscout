defmodule Explorer.Indexer.InternalTransactionFetcherTest do
  use Explorer.DataCase, async: false

  alias Explorer.Chain.Transaction
  alias Explorer.Indexer.{AddressBalanceFetcherCase, InternalTransactionFetcher, PendingTransactionFetcher}

  test "does not try to fetch pending transactions from Explorer.Indexer.PendingTransactionFetcher" do
    start_supervised!({Task.Supervisor, name: Explorer.Indexer.TaskSupervisor})
    AddressBalanceFetcherCase.start_supervised!()
    start_supervised!(PendingTransactionFetcher)

    wait_for_results(fn ->
      Repo.one!(from(transaction in Transaction, where: is_nil(transaction.block_hash), limit: 1))
    end)

    :transaction
    |> insert(hash: "0x3a3eb134e6792ce9403ea4188e5e79693de9e4c94e499db132be086400da79e6")
    |> with_block()

    hash_strings = InternalTransactionFetcher.init([], fn hash_string, acc -> [hash_string | acc] end)

    assert :ok = InternalTransactionFetcher.run(hash_strings, 0)
  end

  describe "init/2" do
    test "does not buffer pending transactions" do
      insert(:transaction)

      assert InternalTransactionFetcher.init([], fn hash_string, acc -> [hash_string | acc] end) == []
    end

    test "buffers collated transactions with unfetched internal transactions" do
      collated_unfetched_transaction =
        :transaction
        |> insert()
        |> with_block()

      assert InternalTransactionFetcher.init([], fn hash_string, acc -> [hash_string | acc] end) == [
               to_string(collated_unfetched_transaction.hash)
             ]
    end

    test "does not buffer collated transactions with fetched internal transactions" do
      :transaction
      |> insert()
      |> with_block(internal_transactions_indexed_at: DateTime.utc_now())

      assert InternalTransactionFetcher.init([], fn hash_string, acc -> [hash_string | acc] end) == []
    end
  end
end
