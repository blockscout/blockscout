defmodule Indexer.Fetcher.Celo.EpochBlockOperationsTest do
  use Utils.CompileTimeEnvHelper, chain_type: [:explorer, :chain_type]
  use EthereumJSONRPC.Case
  use Explorer.DataCase

  import Explorer.Chain.Celo.Helper, only: [blocks_per_epoch: 0]
  import Mox

  alias Indexer.Fetcher.Celo.EpochBlockOperations

  # MUST use global mode because we aren't guaranteed to get
  # `start_supervised`'s pid back fast enough to `allow` it to use
  # expectations and stubs from test's pid.
  setup :set_mox_global

  setup :verify_on_exit!

  if @chain_type == :celo do
    describe "init/3" do
      test "buffers blocks with pending epoch operation", %{
        json_rpc_named_arguments: json_rpc_named_arguments
      } do
        unfetched = insert(:block, number: 1 * blocks_per_epoch())
        insert(:celo_pending_epoch_block_operation, block: unfetched)

        assert [
                 %{
                   block_number: unfetched.number,
                   block_hash: unfetched.hash
                 }
               ] ==
                 EpochBlockOperations.init(
                   [],
                   fn block_number, acc -> [block_number | acc] end,
                   json_rpc_named_arguments
                 )
      end
    end

    test "correctly buffers blocks when :l2_migration_block is set", %{
      json_rpc_named_arguments: json_rpc_named_arguments
    } do
      last_l1_epoch_block_number = 1 * blocks_per_epoch()
      l1_block = insert(:block, number: last_l1_epoch_block_number)
      l2_block = insert(:block, number: 2 * blocks_per_epoch())
      insert(:celo_pending_epoch_block_operation, block: l1_block)
      insert(:celo_pending_epoch_block_operation, block: l2_block)

      Application.put_env(:explorer, :celo, l2_migration_block: last_l1_epoch_block_number)

      assert [
               %{
                 block_number: l1_block.number,
                 block_hash: l1_block.hash
               }
             ] ==
               EpochBlockOperations.init(
                 [],
                 fn block_number, acc -> [block_number | acc] end,
                 json_rpc_named_arguments
               )
    end
  end
end
