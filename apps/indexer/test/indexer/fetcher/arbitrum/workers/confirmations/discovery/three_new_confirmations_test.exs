# SPDX-License-Identifier: LicenseRef-Blockscout
if Application.get_env(:explorer, :chain_type) == :arbitrum do
  defmodule Indexer.Fetcher.Arbitrum.Workers.Confirmations.Discovery.ThreeNewConfirmationsTest do
    use Indexer.Fetcher.Arbitrum.Workers.Confirmations.Discovery.TestCase

    # See `Indexer.Fetcher.Arbitrum.Workers.Confirmations.Discovery.TestCase` for
    # the conventions this suite of files follows.

    # A parent chain range can hold three `SendRootUpdated` events. Then two
    # confirmations are earlier than the last one, and the lookup range of the last
    # confirmation holds both of them.
    #
    # A lookup range holds two earlier confirmations in other conditions as well. The
    # parent chain can already hold two confirmations of the same batch below the
    # discovery range. Then one new event is enough. Only this group holds three new
    # confirmations of one run. Three tests of the group split them over one batch,
    # and the last test of the group splits them over three batches.
    #
    # The discovery must take the newest of the two earlier confirmations. It reads a
    # lookup range in chunks, from the newest chunk to the oldest chunk. It stops at
    # the first chunk which holds a confirmation of the batch. Within one chunk it
    # takes the confirmation with the highest rollup block.
    #
    # The tests of this group give a name to each of the three confirmations. The
    # names are the lowest confirmation, the lower confirmation and the upper
    # confirmation, in the order of their rollup blocks.
    describe "perform/5 with three new confirmations" do
      # The database has one batch with the rollup blocks 1..20. No block of it is
      # confirmed.
      #
      # The three events point to the rollup blocks 5, 10 and 20. All three blocks
      # are in the same batch. The maximum range of one `eth_getLogs` request is wider
      # than each lookup range. Thus the discovery reads each lookup range in one
      # chunk.
      #
      # The lookup range of the upper confirmation holds two confirmations of the
      # batch. They point to the rollup blocks 5 and 10. The discovery must take the
      # block 10, because it is the higher block. As a result, the upper confirmation
      # covers the blocks 11..20.
      #
      # This test is the only test which puts two confirmations of one batch into one
      # chunk. If the discovery takes the block 5, the upper confirmation covers the
      # blocks 6..20. Then the upper confirmation takes the blocks of the lower
      # confirmation again, and the database operation fails.
      #
      # The lookup response of the upper confirmation intentionally puts the newer
      # confirmation first. An `eth_getLogs` response usually puts the older
      # confirmation first.
      #
      # `fetch_and_sort_confirmations_logs/4` adds each block number to the front of
      # its list. It puts the lower block number first. Thus `Enum.sort/2` must put
      # the higher block number first again.
      test "takes the higher of the two earlier confirmations which are in one chunk", %{
        json_rpc_named_arguments: json_rpc_named_arguments
      } do
        batch = seed_batch(@rollup_first_block, 20, @commitment_l1_block)

        lowest_confirmation_transaction_hash = to_string(transaction_hash())
        lower_confirmation_transaction_hash = to_string(transaction_hash())
        upper_confirmation_transaction_hash = to_string(transaction_hash())

        lowest_confirmation_log =
          build_send_root_updated_log(
            rollup_block_hash(batch, 5),
            lowest_confirmation_transaction_hash,
            @lowest_confirmation_l1_block
          )

        lower_confirmation_log =
          build_send_root_updated_log(
            rollup_block_hash(batch, 10),
            lower_confirmation_transaction_hash,
            @lower_confirmation_l1_block
          )

        upper_confirmation_log =
          build_send_root_updated_log(
            rollup_block_hash(batch, 20),
            upper_confirmation_transaction_hash,
            @confirmation_l1_block
          )

        # The mock keeps this order in every response. Thus a response which holds
        # the two earlier confirmations puts the newer one first.
        expect_discovery_of([lower_confirmation_log, lowest_confirmation_log, upper_confirmation_log])

        assert :ok == discover(json_rpc_named_arguments)

        lowest_confirmation = Repo.get_by!(LifecycleTransaction, hash: lowest_confirmation_transaction_hash)
        lower_confirmation = Repo.get_by!(LifecycleTransaction, hash: lower_confirmation_transaction_hash)
        upper_confirmation = Repo.get_by!(LifecycleTransaction, hash: upper_confirmation_transaction_hash)

        assert lowest_confirmation.block_number == @lowest_confirmation_l1_block
        assert DateTime.to_unix(lowest_confirmation.timestamp) == @lowest_confirmation_l1_timestamp

        assert confirmed_blocks(lowest_confirmation) == Enum.to_list(@rollup_first_block..5)
        assert confirmed_blocks(lower_confirmation) == Enum.to_list(6..10)
        assert confirmed_blocks(upper_confirmation) == Enum.to_list(11..20)
        assert unconfirmed_blocks() == []
      end

      # The database has one batch with the rollup blocks 1..20, and no block of it
      # is confirmed. The parent chain holds the commitment of the batch in the block
      # 194, which is close to the three confirmations.
      #
      # The three events point to the rollup blocks 5, 10 and 20. The test before uses
      # the same three blocks. But in this test the maximum range of one `eth_getLogs`
      # request is three blocks. Thus the discovery reads a lookup range in several
      # chunks.
      #
      # The lookup range of the upper confirmation is 194..199. The newest chunk of
      # this range is 197..199, and this chunk holds the confirmation of the block
      # 10. Thus the discovery stops at this chunk. It does not read the chunk
      # 194..196, which holds the confirmation of the block 5.
      #
      # If the discovery also reads the chunk 194..196, it takes the block 5 from
      # that chunk. Then the upper confirmation covers the blocks 6..20, and the
      # blocks 6..10 belong to two confirmations.
      test "stops at the newest chunk which holds an earlier confirmation", %{
        json_rpc_named_arguments: json_rpc_named_arguments
      } do
        batch = seed_batch(@rollup_first_block, 20, @recent_commitment_l1_block)

        lowest_confirmation_transaction_hash = to_string(transaction_hash())
        lower_confirmation_transaction_hash = to_string(transaction_hash())
        upper_confirmation_transaction_hash = to_string(transaction_hash())

        lowest_confirmation_log =
          build_send_root_updated_log(
            rollup_block_hash(batch, 5),
            lowest_confirmation_transaction_hash,
            @lowest_confirmation_l1_block
          )

        lower_confirmation_log =
          build_send_root_updated_log(
            rollup_block_hash(batch, 10),
            lower_confirmation_transaction_hash,
            @lower_confirmation_l1_block
          )

        upper_confirmation_log =
          build_send_root_updated_log(
            rollup_block_hash(batch, 20),
            upper_confirmation_transaction_hash,
            @confirmation_l1_block
          )

        expect_discovery_of([lowest_confirmation_log, lower_confirmation_log, upper_confirmation_log])

        assert :ok == discover(json_rpc_named_arguments, @short_logs_block_range)

        lowest_confirmation = Repo.get_by!(LifecycleTransaction, hash: lowest_confirmation_transaction_hash)
        lower_confirmation = Repo.get_by!(LifecycleTransaction, hash: lower_confirmation_transaction_hash)
        upper_confirmation = Repo.get_by!(LifecycleTransaction, hash: upper_confirmation_transaction_hash)

        assert confirmed_blocks(lowest_confirmation) == Enum.to_list(@rollup_first_block..5)
        assert confirmed_blocks(lower_confirmation) == Enum.to_list(6..10)
        assert confirmed_blocks(upper_confirmation) == Enum.to_list(11..20)
        assert unconfirmed_blocks() == []
      end

      # The database has the same batch with the rollup blocks 1..20, and the parent
      # chain holds the same three events. In this test the maximum range of one
      # `eth_getLogs` request is one block. Thus the newest chunk of the lookup range
      # of the upper confirmation is the block 199, and it holds no event. The chunk
      # 198 holds the confirmation of the block 10.
      #
      # The discovery must read the older chunk when the newest chunk holds no
      # confirmation. If it stops at the empty chunk, it finds no earlier
      # confirmation of the batch. Then the upper confirmation covers the blocks
      # 1..20, and the blocks 1..10 belong to two confirmations.
      #
      # On a production chain the lookup range of a batch covers many blocks, and an
      # empty newest chunk is the usual state.
      test "continues to the older chunk when the newest chunk holds no confirmation", %{
        json_rpc_named_arguments: json_rpc_named_arguments
      } do
        batch = seed_batch(@rollup_first_block, 20, @recent_commitment_l1_block)

        lowest_confirmation_transaction_hash = to_string(transaction_hash())
        lower_confirmation_transaction_hash = to_string(transaction_hash())
        upper_confirmation_transaction_hash = to_string(transaction_hash())

        lowest_confirmation_log =
          build_send_root_updated_log(
            rollup_block_hash(batch, 5),
            lowest_confirmation_transaction_hash,
            @lowest_confirmation_l1_block
          )

        lower_confirmation_log =
          build_send_root_updated_log(
            rollup_block_hash(batch, 10),
            lower_confirmation_transaction_hash,
            @lower_confirmation_l1_block
          )

        upper_confirmation_log =
          build_send_root_updated_log(
            rollup_block_hash(batch, 20),
            upper_confirmation_transaction_hash,
            @confirmation_l1_block
          )

        expect_discovery_of([lowest_confirmation_log, lower_confirmation_log, upper_confirmation_log])

        assert :ok == discover(json_rpc_named_arguments, 1)

        lowest_confirmation = Repo.get_by!(LifecycleTransaction, hash: lowest_confirmation_transaction_hash)
        lower_confirmation = Repo.get_by!(LifecycleTransaction, hash: lower_confirmation_transaction_hash)
        upper_confirmation = Repo.get_by!(LifecycleTransaction, hash: upper_confirmation_transaction_hash)

        assert confirmed_blocks(lowest_confirmation) == Enum.to_list(@rollup_first_block..5)
        assert confirmed_blocks(lower_confirmation) == Enum.to_list(6..10)
        assert confirmed_blocks(upper_confirmation) == Enum.to_list(11..20)
        assert unconfirmed_blocks() == []
      end

      # The database has three batches: the blocks 1..10, the blocks 11..20 and the
      # blocks 21..30. No block is confirmed. The block 15 is not linked to its batch.
      # If the indexer did not handle the whole middle batch, the database has this
      # state.
      #
      # The three events point to the rollup blocks 10, 20 and 30. Each block is the
      # last block of its batch. Thus the lowest confirmation must cover the blocks
      # 1..10, the lower confirmation must cover the blocks 11..20, and the upper
      # confirmation must cover the blocks 21..30.
      #
      # The discovery handles the confirmations in the order of their rollup blocks. It
      # collects the blocks 1..10 for the lowest confirmation. Then the lower
      # confirmation finds a gap between the blocks 14 and 16, thus it gives no block.
      # A confirmation without blocks drops every block which the run collected before
      # it. Therefore the run loses the blocks of the lowest confirmation as well.
      #
      # After that the upper confirmation collects the blocks 21..30 and moves one batch
      # down. In the middle batch the log of the lower confirmation points to the last
      # block of that batch. Thus the walk stops, and the upper confirmation keeps the
      # blocks 21..30. The run writes that confirmation only, and it returns
      # `:confirmation_missed`.
      #
      # The highest confirmed block of the run is the block 30. The discovery marks the
      # messages by the number of that block. Thus a message from the block 5 becomes
      # `:confirmed`, although the block 5 stays unconfirmed.
      #
      # This test is the only one of this group which holds three batches and a state of
      # the database which stops one of the three confirmations. The other tests of the
      # group hold one batch, and they show how the size of the chunk of the lookup
      # changes the boundary of a confirmation.
      #
      # The second part of the test makes the change of the indexer: the indexer links
      # the block 15 to its batch. Then the discovery examines the same parent chain
      # range again. The upper confirmation is a known confirmation of that run, and it
      # keeps its blocks. The two other confirmations arrive together.
      test "writes the upper confirmation only when the confirmation in the middle finds a gap in its batch", %{
        json_rpc_named_arguments: json_rpc_named_arguments
      } do
        lowest_batch = seed_batch(@rollup_first_block, 10, @oldest_commitment_l1_block)
        middle_batch = seed_batch(11, 20, @previous_commitment_l1_block, unlinked_blocks: [15])
        batch = seed_batch(21, 30, @commitment_l1_block)

        lowest_confirmation_transaction_hash = to_string(transaction_hash())
        lower_confirmation_transaction_hash = to_string(transaction_hash())
        upper_confirmation_transaction_hash = to_string(transaction_hash())

        message_below_the_gap = insert_sent_message_from_l2(5)

        expect_discovery_of([
          build_send_root_updated_log(
            rollup_block_hash(lowest_batch, 10),
            lowest_confirmation_transaction_hash,
            @lowest_confirmation_l1_block
          ),
          build_send_root_updated_log(
            rollup_block_hash(middle_batch, 20),
            lower_confirmation_transaction_hash,
            @lower_confirmation_l1_block
          ),
          build_send_root_updated_log(
            rollup_block_hash(batch, 30),
            upper_confirmation_transaction_hash,
            @confirmation_l1_block
          )
        ])

        assert :confirmation_missed == discover(json_rpc_named_arguments)

        assert Repo.get_by(LifecycleTransaction, hash: lowest_confirmation_transaction_hash) == nil
        assert Repo.get_by(LifecycleTransaction, hash: lower_confirmation_transaction_hash) == nil

        upper_confirmation = Repo.get_by!(LifecycleTransaction, hash: upper_confirmation_transaction_hash)
        assert confirmed_blocks(upper_confirmation) == Enum.to_list(21..30)

        assert unconfirmed_blocks() == Enum.to_list(@rollup_first_block..14) ++ Enum.to_list(16..20)

        # The parent chain confirms the block 5 already. Thus this status is correct,
        # and only the link of the block 15 is missing.
        assert message_status(message_below_the_gap) == :confirmed

        link_blocks_to_batch(middle_batch, [15])

        assert :ok == discover(json_rpc_named_arguments)

        lowest_confirmation = Repo.get_by!(LifecycleTransaction, hash: lowest_confirmation_transaction_hash)
        lower_confirmation = Repo.get_by!(LifecycleTransaction, hash: lower_confirmation_transaction_hash)

        assert confirmed_blocks(lowest_confirmation) == Enum.to_list(@rollup_first_block..10)
        assert confirmed_blocks(lower_confirmation) == Enum.to_list(11..20)
        assert confirmed_blocks(upper_confirmation) == Enum.to_list(21..30)
        assert unconfirmed_blocks() == []
      end
    end
  end
end
