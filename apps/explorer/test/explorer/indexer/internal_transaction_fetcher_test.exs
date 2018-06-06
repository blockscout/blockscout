defmodule Explorer.Indexer.InternalTransactionFetcherTest do
  use Explorer.DataCase, async: true

  alias Explorer.Indexer.InternalTransactionFetcher

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
