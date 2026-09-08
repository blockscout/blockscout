# SPDX-License-Identifier: LicenseRef-Blockscout
if Application.get_env(:explorer, :chain_type) == :arbitrum do
  defmodule Indexer.Fetcher.Arbitrum.Workers.Confirmations.Discovery.NoEventTest do
    use Indexer.Fetcher.Arbitrum.Workers.Confirmations.Discovery.TestCase

    # See `Indexer.Fetcher.Arbitrum.Workers.Confirmations.Discovery.TestCase` for
    # the conventions this suite of files follows.

    # A parent chain range can hold no `SendRootUpdated` event. This state is the usual
    # result of one iteration of the discovery on a production chain. A confirmation is
    # rare, and the parent chain holds many blocks.
    describe "perform/5 with no event" do
      # The database has one batch with the rollup blocks 1..10, and no block of it
      # is confirmed.
      #
      # The discovery range holds no event. Thus the discovery examines no rollup
      # block, asks for no other logs, and writes nothing. The blocks of the batch
      # stay unconfirmed. The result is `:ok`.
      #
      # The import gets three empty lists in this scenario. This test is the only one
      # which gives such lists to the import.
      test "writes nothing when the range holds no event", %{json_rpc_named_arguments: json_rpc_named_arguments} do
        seed_batch(@rollup_first_block, 10, @commitment_l1_block)

        expect_discovery_of([])

        assert :ok == discover(json_rpc_named_arguments)

        assert unconfirmed_blocks() == Enum.to_list(@rollup_first_block..10)
      end
    end
  end
end
