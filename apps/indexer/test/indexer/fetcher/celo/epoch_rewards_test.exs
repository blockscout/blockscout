defmodule Indexer.Fetcher.Celo.EpochRewardsTest do
  # MUST be `async: false` so that {:shared, pid} is set for connection to allow CoinBalanceFetcher's self-send to have
  # connection allowed immediately.
  # use EthereumJSONRPC.Case, async: false
  use Explorer.DataCase

  # import Mox
  # import EthereumJSONRPC, only: [integer_to_quantity: 1]

  alias Explorer.Chain.Celo.PendingEpochBlockOperation
  import Explorer.Chain.Celo.Helper, only: [blocks_per_epoch: 0]

  # @moduletag :capture_log

  # # MUST use global mode because we aren't guaranteed to get `start_supervised`'s pid back fast enough to `allow` it to
  # # use expectations and stubs from test's pid.
  # setup :set_mox_global

  # setup :verify_on_exit!

  describe "stream_epoch_blocks_with_unfetched_rewards/2" do
    test "streams blocks with pending epoch operation" do
      unfetched = insert(:block, number: 1 * blocks_per_epoch())
      insert(:celo_pending_epoch_block_operation, block: unfetched)

      {:ok, blocks} =
        PendingEpochBlockOperation.stream_epoch_blocks_with_unfetched_rewards(
          [],
          fn block, acc ->
            [block | acc]
          end
        )

      assert [
               %{
                 block_number: unfetched.number,
                 block_hash: unfetched.hash
               }
             ] == blocks
    end
  end
end
