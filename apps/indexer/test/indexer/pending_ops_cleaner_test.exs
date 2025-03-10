defmodule Indexer.PendingOpsCleanerTest do
  use Explorer.DataCase

  alias Explorer.Chain.PendingBlockOperation
  alias Indexer.PendingOpsCleaner

  describe "init/1" do
    setup do
      config = Application.get_env(:ethereum_jsonrpc, EthereumJSONRPC.Geth)
      Application.put_env(:ethereum_jsonrpc, EthereumJSONRPC.Geth, Keyword.put(config, :block_traceable?, true))

      on_exit(fn -> Application.put_env(:ethereum_jsonrpc, EthereumJSONRPC.Geth, config) end)
    end

    test "deletes non-consensus pending ops on init" do
      block = insert(:block, consensus: false)

      insert(:pending_block_operation, block_hash: block.hash, block_number: block.number)

      assert Repo.one(from(block in PendingBlockOperation, where: block.block_hash == ^block.hash))

      start_supervised!({PendingOpsCleaner, [[interval: :timer.seconds(1)], [name: :PendingOpsTest]]})

      Process.sleep(2_000)

      assert is_nil(Repo.one(from(block in PendingBlockOperation, where: block.block_hash == ^block.hash)))
    end

    test "re-schedules deletion" do
      start_supervised!({PendingOpsCleaner, [[interval: :timer.seconds(1)], [name: :PendingOpsTest]]})

      block = insert(:block, consensus: false)

      insert(:pending_block_operation, block_hash: block.hash, block_number: block.number)

      Process.sleep(2_000)

      assert is_nil(Repo.one(from(block in PendingBlockOperation, where: block.block_hash == ^block.hash)))
    end
  end
end
