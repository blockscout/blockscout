defmodule Indexer.Temporary.InternalTransactionsBlockHashTest do
  use Explorer.DataCase, async: false

  alias Indexer.Temporary.InternalTransactionsBlockHash
  alias Indexer.Temporary.InternalTransactionsBlockHash.Supervisor

  describe "populate_block_hash/1" do
    test "populates blocks hash for internal transactions without block hash" do
      block = insert(:block)
      transaction = :transaction |> insert() |> with_block(block)

      internal_transaction_without_block_hash =
        insert(:internal_transaction, transaction_hash: transaction.hash, index: 0)

      [[name: TaskSupervisor]]
      |> Supervisor.child_spec()
      |> ExUnit.Callbacks.start_supervised!()

      InternalTransactionsBlockHash.populate_block_hash() |> IO.inspect()

      Process.sleep(5_000)
    end
  end
end
