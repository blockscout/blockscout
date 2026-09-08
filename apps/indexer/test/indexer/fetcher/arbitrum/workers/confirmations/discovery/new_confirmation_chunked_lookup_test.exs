# SPDX-License-Identifier: LicenseRef-Blockscout
if Application.get_env(:explorer, :chain_type) == :arbitrum do
  defmodule Indexer.Fetcher.Arbitrum.Workers.Confirmations.Discovery.NewConfirmationChunkedLookupTest do
    use Indexer.Fetcher.Arbitrum.Workers.Confirmations.Discovery.TestCase

    # See `Indexer.Fetcher.Arbitrum.Workers.Confirmations.Discovery.TestCase` for
    # the conventions this suite of files follows.

    # The lookup of an earlier confirmation reads the parent chain from the
    # commitment of the batch to the block before the confirmation under discovery.
    # That range can be wider than the maximum range of one `eth_getLogs` request.
    # Then the discovery reads it in chunks, from the newest chunk to the oldest one,
    # and it stops at the first chunk which holds a confirmation of the batch.
    #
    # This group holds the scenarios where the boundary of the confirmation depends
    # on the content of a chunk. The earlier events of these scenarios are outside
    # the discovery range, thus the discovery reads them only to find the boundary.
    #
    # The group "perform/5 with three new confirmations" holds the chunks of a run
    # with three events inside the discovery range.
    describe "perform/5 with a new confirmation and a chunked lookup of the boundary" do
      # The database has two batches: the blocks 1..10 and the blocks 11..20. No block
      # is confirmed. The maximum range of one `eth_getLogs` request is three blocks,
      # thus the discovery reads the lookup range in several chunks.
      #
      # The parent chain holds three events. The event under discovery points to the
      # rollup block 20. Two earlier events are outside the discovery range: the event
      # of the parent chain block 150 points to the rollup block 15, and the event of
      # the parent chain block 153 points to the rollup block 10.
      #
      # The lookup of the confirmation examines the batch of the blocks 11..20. It
      # reads the chunks from the newest one to the oldest one. The chunk 152..154
      # holds the event of the block 10. That block is below the batch, thus the
      # discovery does not use it, and the lookup continues to the older chunks. The
      # chunk 149..151 holds the event of the block 15, which is in the middle of the
      # batch. Thus the lookup stops there, and the confirmation covers the blocks
      # 16..20.
      #
      # This test is not redundant. The test "stops at the newest chunk which holds an
      # earlier confirmation" stops at a chunk with a confirmation of the batch. The
      # test "continues to the older chunk when the newest chunk holds no confirmation"
      # continues over an empty chunk. This test is the only one which continues over a
      # chunk which holds an event of another batch. Thus it shows that the lookup does
      # not read "the chunk holds a log" as "the chunk holds the boundary".
      test "continues to the older chunk when the newest chunk holds an event of another batch", %{
        json_rpc_named_arguments: json_rpc_named_arguments
      } do
        previous_batch = seed_batch(@rollup_first_block, 10, @previous_commitment_l1_block)
        batch = seed_batch(11, 20, @commitment_l1_block)

        boundary_confirmation_transaction_hash = to_string(transaction_hash())
        other_batch_confirmation_transaction_hash = to_string(transaction_hash())
        confirmation_transaction_hash = to_string(transaction_hash())

        expect_discovery_of([
          build_send_root_updated_log(
            rollup_block_hash(batch, 15),
            boundary_confirmation_transaction_hash,
            @earlier_confirmation_l1_block
          ),
          build_send_root_updated_log(
            rollup_block_hash(previous_batch, 10),
            other_batch_confirmation_transaction_hash,
            @earlier_confirmation_l1_block + 3
          ),
          build_send_root_updated_log(
            rollup_block_hash(batch, 20),
            confirmation_transaction_hash,
            @confirmation_l1_block
          )
        ])

        assert :ok == discover(json_rpc_named_arguments, @short_logs_block_range)

        confirmation = Repo.get_by!(LifecycleTransaction, hash: confirmation_transaction_hash)
        assert confirmed_blocks(confirmation) == Enum.to_list(16..20)

        # The discovery reads the two earlier logs only to find the bottom of the
        # current confirmation. It imports neither of the two transactions.
        refute Repo.get_by(LifecycleTransaction, hash: boundary_confirmation_transaction_hash)
        refute Repo.get_by(LifecycleTransaction, hash: other_batch_confirmation_transaction_hash)

        assert unconfirmed_blocks() == Enum.to_list(@rollup_first_block..15)
      end

      # The database has one batch of the blocks 1..10. No block of it is confirmed.
      # The rollup blocks 11..20 are also in the database, but no batch of the database
      # holds them. If the indexer did not handle the batch of those blocks, the
      # database has this state.
      #
      # The parent chain holds three events. The event under discovery points to the
      # rollup block 10. Two earlier events are outside the discovery range, and both
      # of them are in one chunk of the lookup: the event of the parent chain block 150
      # points to the rollup block 5, and the event of the parent chain block 151
      # points to the rollup block 20.
      #
      # The lookup reads the chunk and takes the number of the rollup block of each log
      # of it. The block 20 holds no batch, thus the discovery cannot find its number.
      # The lookup stops on that log and gives an error, although the same chunk holds
      # the log of the block 5, which is the boundary of the confirmation. Thus the
      # discovery writes nothing, and it returns `:confirmation_missed`.
      #
      # The test "postpones the confirmation when an out-of-range earlier event points
      # to a block without a batch" holds the same error of the lookup with one earlier
      # event. This test is the only one where the chunk of the error also holds a
      # usable boundary.
      #
      # The second part of the test makes the change of the indexer: the indexer writes
      # the batch of the blocks 11..20. Then the discovery examines the same parent
      # chain range again. The number of the block 20 is known now, and that block is
      # above the batch of the confirmation. Thus the lookup takes the block 5 as the
      # boundary, and the confirmation covers the blocks 6..10.
      test "postpones the confirmation when one event of the chunk of the boundary points to a block without a batch",
           %{json_rpc_named_arguments: json_rpc_named_arguments} do
        batch = seed_batch(@rollup_first_block, 10, @commitment_l1_block)
        blocks_without_batch = seed_blocks_without_batch(11, 20)

        boundary_confirmation_transaction_hash = to_string(transaction_hash())
        unresolvable_confirmation_transaction_hash = to_string(transaction_hash())
        confirmation_transaction_hash = to_string(transaction_hash())

        expect_discovery_of([
          build_send_root_updated_log(
            rollup_block_hash(batch, 5),
            boundary_confirmation_transaction_hash,
            @earlier_confirmation_l1_block
          ),
          build_send_root_updated_log(
            rollup_block_hash(blocks_without_batch, 20),
            unresolvable_confirmation_transaction_hash,
            @earlier_confirmation_l1_block + 1
          ),
          build_send_root_updated_log(
            rollup_block_hash(batch, 10),
            confirmation_transaction_hash,
            @confirmation_l1_block
          )
        ])

        assert :confirmation_missed == discover(json_rpc_named_arguments)

        assert Repo.get_by(LifecycleTransaction, hash: confirmation_transaction_hash) == nil
        assert unconfirmed_blocks() == Enum.to_list(@rollup_first_block..10)

        seed_batch_of_blocks(blocks_without_batch, @previous_commitment_l1_block)

        assert :ok == discover(json_rpc_named_arguments)

        confirmation = Repo.get_by!(LifecycleTransaction, hash: confirmation_transaction_hash)
        assert confirmed_blocks(confirmation) == Enum.to_list(6..10)

        refute Repo.get_by(LifecycleTransaction, hash: boundary_confirmation_transaction_hash)
        refute Repo.get_by(LifecycleTransaction, hash: unresolvable_confirmation_transaction_hash)

        # The blocks 1..5 stay for the earlier confirmation of the block 5. The blocks
        # 11..20 stay for the confirmation of the block 20.
        assert unconfirmed_blocks() == Enum.to_list(@rollup_first_block..5) ++ Enum.to_list(11..20)
      end

      # The database has one batch of the blocks 1..20. No block of it is confirmed.
      # The maximum range of one `eth_getLogs` request is wider than the lookup range,
      # thus the discovery reads the lookup range in one chunk.
      #
      # The parent chain holds three events. The event under discovery points to the
      # rollup block 20. Two earlier events are outside the discovery range, and they
      # hold the inverted order: the event of the parent chain block 150 points to the
      # rollup block 10, and the newer event of the parent chain block 160 points to
      # the lower rollup block 5.
      #
      # Both earlier logs are in one chunk. The lookup sorts the rollup blocks of a
      # chunk by their numbers, and it takes the highest block of the batch. Thus it
      # takes the block 10, and not the block of the newer parent chain block. As a
      # result, the confirmation covers the blocks 11..20.
      #
      # The test "takes the higher of the two earlier confirmations which are in one
      # chunk" holds two earlier confirmations of one chunk as well. In that test the
      # order of the parent chain blocks is the order of the rollup blocks. This test
      # is the only one where the two orders are inverted. Thus it shows that the
      # boundary comes from the number of the rollup block, and not from the position
      # on the parent chain.
      test "takes the highest rollup block of the two earlier confirmations of the inverted order", %{
        json_rpc_named_arguments: json_rpc_named_arguments
      } do
        batch = seed_batch(@rollup_first_block, 20, @commitment_l1_block)

        higher_confirmation_transaction_hash = to_string(transaction_hash())
        lower_confirmation_transaction_hash = to_string(transaction_hash())
        confirmation_transaction_hash = to_string(transaction_hash())

        expect_discovery_of([
          build_send_root_updated_log(
            rollup_block_hash(batch, 10),
            higher_confirmation_transaction_hash,
            @earlier_confirmation_l1_block
          ),
          build_send_root_updated_log(
            rollup_block_hash(batch, 5),
            lower_confirmation_transaction_hash,
            @earlier_confirmation_l1_block + 10
          ),
          build_send_root_updated_log(
            rollup_block_hash(batch, 20),
            confirmation_transaction_hash,
            @confirmation_l1_block
          )
        ])

        assert :ok == discover(json_rpc_named_arguments)

        confirmation = Repo.get_by!(LifecycleTransaction, hash: confirmation_transaction_hash)
        assert confirmed_blocks(confirmation) == Enum.to_list(11..20)

        refute Repo.get_by(LifecycleTransaction, hash: higher_confirmation_transaction_hash)
        refute Repo.get_by(LifecycleTransaction, hash: lower_confirmation_transaction_hash)

        assert unconfirmed_blocks() == Enum.to_list(@rollup_first_block..10)
      end

      # The database holds the same batch of the blocks 1..20, and the parent chain
      # holds the same three events as the test before. In this test the maximum range
      # of one `eth_getLogs` request is three blocks. Thus the discovery reads the
      # lookup range in several chunks, and the two earlier events fall into two
      # different chunks.
      #
      # The boundary of the confirmation must not depend on the size of the chunk. The
      # earlier confirmation of the block 10 covers the blocks up to that block, thus
      # the confirmation under discovery must cover the blocks 11..20 here as well.
      #
      # The lookup reads the chunks from the newest one to the oldest one, and it stops
      # at the first chunk which holds a confirmation of the batch. The chunk 158..160
      # holds the event of the rollup block 5, which is in the batch. Thus the lookup
      # stops there, and it does not read the chunk with the event of the rollup block
      # 10. As a result, the confirmation covers the blocks 6..20, and the blocks 6..10
      # belong to two confirmations: to this one and to the earlier confirmation of the
      # block 10.
      #
      # This pair of tests is the only place which shows that the size of the chunk
      # changes the result for the same events and the same state of the database.
      @tag skip: "Defect: the size of the chunk of the lookup changes the boundary of the confirmation"
      test "takes the same boundary when the two earlier confirmations of the inverted order are in two chunks", %{
        json_rpc_named_arguments: json_rpc_named_arguments
      } do
        batch = seed_batch(@rollup_first_block, 20, @commitment_l1_block)

        higher_confirmation_transaction_hash = to_string(transaction_hash())
        lower_confirmation_transaction_hash = to_string(transaction_hash())
        confirmation_transaction_hash = to_string(transaction_hash())

        expect_discovery_of([
          build_send_root_updated_log(
            rollup_block_hash(batch, 10),
            higher_confirmation_transaction_hash,
            @earlier_confirmation_l1_block
          ),
          build_send_root_updated_log(
            rollup_block_hash(batch, 5),
            lower_confirmation_transaction_hash,
            @earlier_confirmation_l1_block + 10
          ),
          build_send_root_updated_log(
            rollup_block_hash(batch, 20),
            confirmation_transaction_hash,
            @confirmation_l1_block
          )
        ])

        assert :ok == discover(json_rpc_named_arguments, @short_logs_block_range)

        confirmation = Repo.get_by!(LifecycleTransaction, hash: confirmation_transaction_hash)
        assert confirmed_blocks(confirmation) == Enum.to_list(11..20)

        refute Repo.get_by(LifecycleTransaction, hash: higher_confirmation_transaction_hash)
        refute Repo.get_by(LifecycleTransaction, hash: lower_confirmation_transaction_hash)

        assert unconfirmed_blocks() == Enum.to_list(@rollup_first_block..10)
      end
    end
  end
end
