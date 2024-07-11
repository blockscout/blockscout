defmodule Indexer.Fetcher.Celo.EpochBlockOperationsTest do
  # MUST be `async: false` so that {:shared, pid} is set for connection to allow CoinBalanceFetcher's self-send to have
  # connection allowed immediately.
  # use EthereumJSONRPC.Case, async: false

  use EthereumJSONRPC.Case
  use Explorer.DataCase

  import Mox
  # import EthereumJSONRPC, only: [integer_to_quantity: 1]

  import Explorer.Chain.Celo.Helper, only: [blocks_per_epoch: 0]

  alias Indexer.Fetcher.Celo.EpochBlockOperations

  # @moduletag :capture_log

  # MUST use global mode because we aren't guaranteed to get `start_supervised`'s pid back fast enough to `allow` it to
  # use expectations and stubs from test's pid.
  setup :set_mox_global

  setup :verify_on_exit!

  if Application.compile_env(:explorer, :chain_type) == :celo do
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
  end
end
