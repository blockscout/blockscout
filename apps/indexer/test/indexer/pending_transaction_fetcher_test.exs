defmodule Explorer.Indexer.PendingTransactionFetcherTest do
  # `async: false` due to use of named GenServer
  use Explorer.DataCase, async: false

  alias Explorer.Chain.Transaction
  alias Explorer.Indexer.PendingTransactionFetcher

  describe "start_link/1" do
    # this test may fail if Sokol so low volume that the pending transactions are empty for too long
    test "starts fetching pending transactions" do
      assert Repo.aggregate(Transaction, :count, :hash) == 0

      start_supervised!({Task.Supervisor, name: Explorer.Indexer.TaskSupervisor})
      start_supervised!(PendingTransactionFetcher)

      wait_for_results(fn ->
        Repo.one!(from(transaction in Transaction, where: is_nil(transaction.block_hash), limit: 1))
      end)

      assert Repo.aggregate(Transaction, :count, :hash) >= 1
    end
  end
end
