# SPDX-License-Identifier: LicenseRef-Blockscout
if Application.get_env(:explorer, :chain_type) == :arbitrum do
  defmodule Indexer.Fetcher.Arbitrum.Workers.Confirmations.DiscoveryTest do
    use EthereumJSONRPC.Case, async: false
    use Explorer.DataCase

    import EthereumJSONRPC, only: [integer_to_quantity: 1, quantity_to_integer: 1]
    import Mox

    alias EthereumJSONRPC.Arbitrum.Constants.Events, as: ArbitrumEvents
    alias Explorer.Chain.Arbitrum.BatchBlock
    alias Explorer.Chain.Arbitrum.LifecycleTransaction
    alias Explorer.Chain.Arbitrum.Message
    alias Explorer.Repo
    alias Indexer.Fetcher.Arbitrum.Workers.Confirmations.Discovery

    @outbox_address "0x0b9857ae2d4a3dbe74ffe1d7df045bb7f96e4840"

    # One call of `perform/5` reads the logs of this parent chain range. The
    # `SendRootUpdated` event of each test is in the parent chain block 200.
    @discovery_l1_start_block 195
    @discovery_l1_end_block 205
    @confirmation_l1_block 200
    @confirmation_l1_timestamp 1_700_000_000

    # The parent chain block of an earlier confirmation, if a test has one. This
    # block is between the commitments of the batches and the confirmation under
    # discovery. Thus the discovery can find that earlier confirmation.
    @earlier_confirmation_l1_block 150

    # The parent chain blocks of the commitment transactions of the batches. The
    # first one belongs to the batch with the confirmed block. The other ones
    # belong to the batches below it.
    @commitment_l1_block 100
    @previous_commitment_l1_block 90
    @oldest_commitment_l1_block 80

    # The lowest indexed rollup block. The oldest batch of each test starts here.
    # Thus the discovery cannot move below this block.
    @rollup_first_block 1

    setup :verify_on_exit!

    setup %{json_rpc_named_arguments: json_rpc_named_arguments} do
      mocked_json_rpc_named_arguments = Keyword.put(json_rpc_named_arguments, :transport, EthereumJSONRPC.Mox)

      %{json_rpc_named_arguments: mocked_json_rpc_named_arguments}
    end

    # A `SendRootUpdated` event on the parent chain confirms one rollup block. The
    # event also confirms all rollup blocks below that block, down to the block of
    # the confirmation before it.
    #
    # Each test in this group gives the discovery one such event. The parent chain
    # transaction of the event is not in the database yet. Thus the discovery must
    # find all rollup blocks that belong to this confirmation.
    #
    # The discovery starts with the batch that contains the confirmed block. Then it
    # can move down, from batch to batch. The walk stops on one of these conditions:
    #   - the discovery finds an earlier confirmation inside the batch
    #   - all blocks of the batch below are confirmed already
    #   - the batch starts at the lowest indexed rollup block
    #
    # To find an earlier confirmation, the discovery reads the parent chain logs
    # between the commitment of the batch and the confirmation under discovery.
    describe "perform/5 with a new confirmation" do
      # The database has one batch with the rollup blocks 1..10. No block of it is
      # confirmed.
      #
      # The event points to the rollup block 10, which is the highest block of the
      # batch. No earlier confirmation exists on the parent chain. The batch starts
      # at the lowest indexed rollup block. As a result, the confirmation covers the
      # full batch.
      #
      # The discovery also changes the status of the L2-to-L1 messages. A message
      # that was sent in the block 10 or below becomes `:confirmed`. A message from
      # a higher block keeps the status `:sent`.
      test "confirms every rollup block of the batch and the L2-to-L1 messages below the confirmed block", %{
        json_rpc_named_arguments: json_rpc_named_arguments
      } do
        batch = seed_batch(@rollup_first_block, 10, @commitment_l1_block)

        confirmation_transaction_hash = to_string(transaction_hash())
        confirmed_message = insert_sent_message_from_l2(9)
        not_yet_confirmed_message = insert_sent_message_from_l2(11)

        expect_rpc(
          %{
            # The range of the discovery, which contains the confirmation log.
            {@discovery_l1_start_block, @discovery_l1_end_block} => [
              build_send_root_updated_log(
                rollup_block_hash(batch, 10),
                confirmation_transaction_hash,
                @confirmation_l1_block
              )
            ],
            # The range between the commitment of the batch and the confirmation.
            # It contains no earlier confirmation.
            {@commitment_l1_block, @confirmation_l1_block - 1} => []
          },
          %{@confirmation_l1_block => @confirmation_l1_timestamp}
        )

        assert :ok == discover(json_rpc_named_arguments)

        assert drain_get_logs_ranges() == [
                 {@discovery_l1_start_block, @discovery_l1_end_block},
                 {@commitment_l1_block, @confirmation_l1_block - 1}
               ]

        # The parent chain transaction of the event becomes a lifecycle transaction.
        confirmation = Repo.get_by!(LifecycleTransaction, hash: confirmation_transaction_hash)
        assert confirmation.block_number == @confirmation_l1_block
        assert DateTime.to_unix(confirmation.timestamp) == @confirmation_l1_timestamp
        assert confirmation.status == :unfinalized

        # The full batch is linked to that lifecycle transaction.
        assert confirmed_blocks(confirmation) == Enum.to_list(@rollup_first_block..10)
        assert message_status(confirmed_message) == :confirmed
        assert message_status(not_yet_confirmed_message) == :sent
      end

      # The database has one batch with the rollup blocks 1..10. An earlier
      # confirmation is known already, and it covers the blocks 1..5.
      #
      # The event points to the rollup block 10. In the parent chain range of the
      # batch, the discovery finds the log of the earlier confirmation. That log
      # points to the rollup block 5, which is in the middle of the batch. Thus the
      # new confirmation covers the blocks 6..10, and the walk stops in this batch.
      test "links only the blocks above an earlier confirmation which happened in the middle of the same batch", %{
        json_rpc_named_arguments: json_rpc_named_arguments
      } do
        batch = seed_batch(@rollup_first_block, 10, @commitment_l1_block)

        earlier_confirmation = insert_confirmation(@earlier_confirmation_l1_block)
        mark_confirmed(@rollup_first_block..5, earlier_confirmation)

        confirmation_transaction_hash = to_string(transaction_hash())

        expect_rpc(
          %{
            {@discovery_l1_start_block, @discovery_l1_end_block} => [
              build_send_root_updated_log(
                rollup_block_hash(batch, 10),
                confirmation_transaction_hash,
                @confirmation_l1_block
              )
            ],
            {@commitment_l1_block, @confirmation_l1_block - 1} => [
              build_send_root_updated_log(
                rollup_block_hash(batch, 5),
                to_string(earlier_confirmation.hash),
                @earlier_confirmation_l1_block
              )
            ]
          },
          %{@confirmation_l1_block => @confirmation_l1_timestamp}
        )

        assert :ok == discover(json_rpc_named_arguments)

        # The walk stops inside the batch, thus no other range is requested.
        assert drain_get_logs_ranges() == [
                 {@discovery_l1_start_block, @discovery_l1_end_block},
                 {@commitment_l1_block, @confirmation_l1_block - 1}
               ]

        confirmation = Repo.get_by!(LifecycleTransaction, hash: confirmation_transaction_hash)
        assert confirmed_blocks(confirmation) == Enum.to_list(6..10)
        assert confirmed_blocks(earlier_confirmation) == Enum.to_list(@rollup_first_block..5)
      end

      # The database has two batches: the blocks 1..10 and the blocks 11..20. An
      # earlier confirmation covers the full first batch. The blocks 11..20 are not
      # confirmed.
      #
      # The event points to the rollup block 20. The discovery finds no earlier
      # confirmation in the parent chain range of the second batch. Thus it moves to
      # the first batch. The database shows that all blocks of that batch are
      # confirmed. As a result, the walk stops, and the discovery asks for no logs
      # for the first batch.
      test "stops at the previous batch when all of its blocks are already confirmed", %{
        json_rpc_named_arguments: json_rpc_named_arguments
      } do
        seed_batch(@rollup_first_block, 10, @previous_commitment_l1_block)
        batch = seed_batch(11, 20, @commitment_l1_block)

        earlier_confirmation = insert_confirmation(@earlier_confirmation_l1_block)
        mark_confirmed(@rollup_first_block..10, earlier_confirmation)

        confirmation_transaction_hash = to_string(transaction_hash())

        expect_rpc(
          %{
            {@discovery_l1_start_block, @discovery_l1_end_block} => [
              build_send_root_updated_log(
                rollup_block_hash(batch, 20),
                confirmation_transaction_hash,
                @confirmation_l1_block
              )
            ],
            {@commitment_l1_block, @confirmation_l1_block - 1} => []
          },
          %{@confirmation_l1_block => @confirmation_l1_timestamp}
        )

        assert :ok == discover(json_rpc_named_arguments)

        # The database alone shows that the first batch is confirmed. Thus the
        # discovery requests no logs for the range of that batch.
        assert drain_get_logs_ranges() == [
                 {@discovery_l1_start_block, @discovery_l1_end_block},
                 {@commitment_l1_block, @confirmation_l1_block - 1}
               ]

        confirmation = Repo.get_by!(LifecycleTransaction, hash: confirmation_transaction_hash)
        assert confirmed_blocks(confirmation) == Enum.to_list(11..20)
        assert confirmed_blocks(earlier_confirmation) == Enum.to_list(@rollup_first_block..10)
        assert unconfirmed_blocks() == []
      end

      # The database has two batches: the blocks 1..10 and the blocks 11..20. No
      # block is confirmed. This state is usual for the historical discovery,
      # because that discovery moves backward and processes the newer confirmations
      # first.
      #
      # The event points to the rollup block 20. An earlier confirmation exists on
      # the parent chain, but the database does not know it yet. That confirmation
      # points to the rollup block 10, which is the last block of the first batch.
      #
      # In the range of the second batch, the log of the earlier confirmation points
      # below the first block of that batch. Thus the discovery ignores it there and
      # moves one batch down. In the range of the first batch, the same log points
      # exactly to the last block. As a result, the full first batch belongs to the
      # earlier confirmation, and the new confirmation covers the blocks 11..20.
      test "stops at the previous batch when an earlier confirmation covers exactly its last block", %{
        json_rpc_named_arguments: json_rpc_named_arguments
      } do
        previous_batch = seed_batch(@rollup_first_block, 10, @previous_commitment_l1_block)
        batch = seed_batch(11, 20, @commitment_l1_block)

        earlier_confirmation_log =
          build_send_root_updated_log(
            rollup_block_hash(previous_batch, 10),
            to_string(transaction_hash()),
            @earlier_confirmation_l1_block
          )

        confirmation_transaction_hash = to_string(transaction_hash())

        expect_rpc(
          %{
            {@discovery_l1_start_block, @discovery_l1_end_block} => [
              build_send_root_updated_log(
                rollup_block_hash(batch, 20),
                confirmation_transaction_hash,
                @confirmation_l1_block
              )
            ],
            # The range of the second batch, then the range of the first batch.
            {@commitment_l1_block, @confirmation_l1_block - 1} => [earlier_confirmation_log],
            {@previous_commitment_l1_block, @confirmation_l1_block - 1} => [earlier_confirmation_log]
          },
          %{@confirmation_l1_block => @confirmation_l1_timestamp}
        )

        assert :ok == discover(json_rpc_named_arguments)

        assert drain_get_logs_ranges() == [
                 {@discovery_l1_start_block, @discovery_l1_end_block},
                 {@commitment_l1_block, @confirmation_l1_block - 1},
                 {@previous_commitment_l1_block, @confirmation_l1_block - 1}
               ]

        confirmation = Repo.get_by!(LifecycleTransaction, hash: confirmation_transaction_hash)
        assert confirmed_blocks(confirmation) == Enum.to_list(11..20)

        # The blocks of the first batch stay for the earlier confirmation. One of
        # the next iterations of the discovery finds that confirmation.
        assert unconfirmed_blocks() == Enum.to_list(@rollup_first_block..10)
      end

      # The database has two batches: the blocks 1..10 and the blocks 11..20. An
      # earlier confirmation covers the blocks 1..5.
      #
      # The event points to the rollup block 20. In the range of the second batch,
      # the log of the earlier confirmation points to the rollup block 5. That block
      # is below the batch, thus the discovery moves one batch down. In the range of
      # the first batch, the same log points to the block 5, which is in the middle
      # of that batch. As a result, the new confirmation covers the blocks 6..20.
      test "spans two batches down to an earlier confirmation in the middle of the previous batch", %{
        json_rpc_named_arguments: json_rpc_named_arguments
      } do
        previous_batch = seed_batch(@rollup_first_block, 10, @previous_commitment_l1_block)
        batch = seed_batch(11, 20, @commitment_l1_block)

        earlier_confirmation = insert_confirmation(@earlier_confirmation_l1_block)
        mark_confirmed(@rollup_first_block..5, earlier_confirmation)

        earlier_confirmation_log =
          build_send_root_updated_log(
            rollup_block_hash(previous_batch, 5),
            to_string(earlier_confirmation.hash),
            @earlier_confirmation_l1_block
          )

        confirmation_transaction_hash = to_string(transaction_hash())

        expect_rpc(
          %{
            {@discovery_l1_start_block, @discovery_l1_end_block} => [
              build_send_root_updated_log(
                rollup_block_hash(batch, 20),
                confirmation_transaction_hash,
                @confirmation_l1_block
              )
            ],
            {@commitment_l1_block, @confirmation_l1_block - 1} => [earlier_confirmation_log],
            {@previous_commitment_l1_block, @confirmation_l1_block - 1} => [earlier_confirmation_log]
          },
          %{@confirmation_l1_block => @confirmation_l1_timestamp}
        )

        assert :ok == discover(json_rpc_named_arguments)

        assert drain_get_logs_ranges() == [
                 {@discovery_l1_start_block, @discovery_l1_end_block},
                 {@commitment_l1_block, @confirmation_l1_block - 1},
                 {@previous_commitment_l1_block, @confirmation_l1_block - 1}
               ]

        # The confirmation covers the end of the first batch and the full second
        # batch.
        confirmation = Repo.get_by!(LifecycleTransaction, hash: confirmation_transaction_hash)
        assert confirmed_blocks(confirmation) == Enum.to_list(6..20)
        assert confirmed_blocks(earlier_confirmation) == Enum.to_list(@rollup_first_block..5)
      end

      # The database has three batches: the blocks 1..5, the blocks 6..10 and the
      # blocks 11..15. No block is confirmed, and no earlier confirmation exists on
      # the parent chain.
      #
      # The event points to the rollup block 15. The discovery finds no earlier
      # confirmation in the range of each batch. Thus it moves down from batch to
      # batch. The first batch starts at the lowest indexed rollup block. As a
      # result, the walk stops there, and the confirmation covers the blocks 1..15.
      test "walks back through several batches until the lowest indexed rollup block", %{
        json_rpc_named_arguments: json_rpc_named_arguments
      } do
        seed_batch(@rollup_first_block, 5, @oldest_commitment_l1_block)
        seed_batch(6, 10, @previous_commitment_l1_block)
        batch = seed_batch(11, 15, @commitment_l1_block)

        confirmation_transaction_hash = to_string(transaction_hash())

        expect_rpc(
          %{
            {@discovery_l1_start_block, @discovery_l1_end_block} => [
              build_send_root_updated_log(
                rollup_block_hash(batch, 15),
                confirmation_transaction_hash,
                @confirmation_l1_block
              )
            ],
            # No range contains an earlier confirmation. Thus the walk continues
            # down to the lowest indexed rollup block.
            {@commitment_l1_block, @confirmation_l1_block - 1} => [],
            {@previous_commitment_l1_block, @confirmation_l1_block - 1} => [],
            {@oldest_commitment_l1_block, @confirmation_l1_block - 1} => []
          },
          %{@confirmation_l1_block => @confirmation_l1_timestamp}
        )

        assert :ok == discover(json_rpc_named_arguments)

        assert drain_get_logs_ranges() == [
                 {@discovery_l1_start_block, @discovery_l1_end_block},
                 {@commitment_l1_block, @confirmation_l1_block - 1},
                 {@previous_commitment_l1_block, @confirmation_l1_block - 1},
                 {@oldest_commitment_l1_block, @confirmation_l1_block - 1}
               ]

        confirmation = Repo.get_by!(LifecycleTransaction, hash: confirmation_transaction_hash)
        assert confirmed_blocks(confirmation) == Enum.to_list(@rollup_first_block..15)
      end

      # The database has one batch with the rollup blocks 1..10. The blocks 9 and 10
      # are linked to a parent chain transaction which is not the confirmation of
      # this range. The blocks 1..8 are not confirmed.
      #
      # Such a state occurs after a re-org, or after a wrong link. The event points
      # to the rollup block 10. Thus the discovery takes the blocks 9 and 10 from
      # the other transaction, and links the full batch to the new confirmation.
      test "re-links the blocks on top of the batch which were confirmed by another transaction", %{
        json_rpc_named_arguments: json_rpc_named_arguments
      } do
        batch = seed_batch(@rollup_first_block, 10, @commitment_l1_block)

        wrong_confirmation = insert_confirmation(@earlier_confirmation_l1_block)
        mark_confirmed(9..10, wrong_confirmation)

        confirmation_transaction_hash = to_string(transaction_hash())

        expect_rpc(
          %{
            {@discovery_l1_start_block, @discovery_l1_end_block} => [
              build_send_root_updated_log(
                rollup_block_hash(batch, 10),
                confirmation_transaction_hash,
                @confirmation_l1_block
              )
            ],
            {@commitment_l1_block, @confirmation_l1_block - 1} => []
          },
          %{@confirmation_l1_block => @confirmation_l1_timestamp}
        )

        assert :ok == discover(json_rpc_named_arguments)

        # The full batch is linked to the new confirmation. The other transaction
        # keeps no block.
        confirmation = Repo.get_by!(LifecycleTransaction, hash: confirmation_transaction_hash)
        assert confirmed_blocks(confirmation) == Enum.to_list(@rollup_first_block..10)
        assert confirmed_blocks(wrong_confirmation) == []
      end
    end

    # The parent chain transaction of the event is in the database already, as a
    # lifecycle transaction. Thus the rollup blocks of this confirmation are linked
    # to it already.
    #
    # In this condition the discovery does not examine the rollup blocks one more
    # time. It only compares the parent chain block number and the timestamp of the
    # known transaction with the values from the event. A difference between them
    # can occur after a re-org.
    describe "perform/5 with an already known confirmation" do
      # The database has one batch with the rollup blocks 1..10, and no block of it
      # is confirmed. The lifecycle transaction of the confirmation is in the
      # database with the parent chain block 190.
      #
      # The event shows the same transaction in the parent chain block 200, because
      # a re-org moved it. Thus the discovery writes the new block number and the
      # new timestamp into the same record. The rollup blocks stay as they are, and
      # the discovery asks for no more logs.
      test "updates the confirmation transaction when its parent chain block changed", %{
        json_rpc_named_arguments: json_rpc_named_arguments
      } do
        batch = seed_batch(@rollup_first_block, 10, @commitment_l1_block)

        existing_confirmation = insert_confirmation(@confirmation_l1_block - 10)

        expect_rpc(
          %{
            {@discovery_l1_start_block, @discovery_l1_end_block} => [
              build_send_root_updated_log(
                rollup_block_hash(batch, 10),
                to_string(existing_confirmation.hash),
                @confirmation_l1_block
              )
            ]
          },
          %{@confirmation_l1_block => @confirmation_l1_timestamp}
        )

        assert :ok == discover(json_rpc_named_arguments)

        # The discovery does not look for an earlier confirmation.
        assert drain_get_logs_ranges() == [{@discovery_l1_start_block, @discovery_l1_end_block}]

        updated_confirmation = Repo.get_by!(LifecycleTransaction, hash: existing_confirmation.hash)
        assert updated_confirmation.id == existing_confirmation.id
        assert updated_confirmation.block_number == @confirmation_l1_block
        assert DateTime.to_unix(updated_confirmation.timestamp) == @confirmation_l1_timestamp
        assert updated_confirmation.status == existing_confirmation.status

        assert unconfirmed_blocks() == Enum.to_list(@rollup_first_block..10)
      end

      # The lifecycle transaction of the confirmation is in the database. Its parent
      # chain block number and its timestamp are equal to the values in the event.
      #
      # The discovery finds no difference, thus it writes nothing and the result is
      # `:ok`. This is the usual result when the same parent chain range is
      # processed one more time.
      test "leaves the confirmation transaction untouched when nothing changed", %{
        json_rpc_named_arguments: json_rpc_named_arguments
      } do
        existing_confirmation = insert_confirmation(@confirmation_l1_block, @confirmation_l1_timestamp)

        expect_rpc(
          %{
            {@discovery_l1_start_block, @discovery_l1_end_block} => [
              build_send_root_updated_log(
                to_string(block_hash()),
                to_string(existing_confirmation.hash),
                @confirmation_l1_block
              )
            ]
          },
          %{@confirmation_l1_block => @confirmation_l1_timestamp}
        )

        assert :ok == discover(json_rpc_named_arguments)

        assert drain_get_logs_ranges() == [{@discovery_l1_start_block, @discovery_l1_end_block}]

        assert Repo.aggregate(LifecycleTransaction, :count) == 1

        kept_confirmation = Repo.get_by!(LifecycleTransaction, hash: existing_confirmation.hash)
        assert kept_confirmation.id == existing_confirmation.id
        assert kept_confirmation.block_number == @confirmation_l1_block
        assert DateTime.compare(kept_confirmation.timestamp, existing_confirmation.timestamp) == :eq
        assert kept_confirmation.status == existing_confirmation.status
      end
    end

    # Runs the discovery over the parent chain range holding the confirmation.
    defp discover(json_rpc_named_arguments) do
      Discovery.perform(
        @outbox_address,
        @discovery_l1_start_block,
        @discovery_l1_end_block,
        %{
          json_rpc_named_arguments: json_rpc_named_arguments,
          logs_block_range: 1000,
          chunk_size: 10,
          track_finalization: true,
          finalized_confirmations: true
        },
        @rollup_first_block
      )
    end

    # Inserts a batch with its commitment transaction and the rollup blocks
    # belonging to it, all of them unconfirmed (`confirmation_id` is `nil`).
    # Returns the batch together with the inserted blocks keyed by block number.
    defp seed_batch(start_block, end_block, commitment_l1_block) do
      commitment_transaction = insert(:arbitrum_lifecycle_transaction, block_number: commitment_l1_block)

      batch =
        insert(:arbitrum_l1_batch,
          start_block: start_block,
          end_block: end_block,
          commitment_id: commitment_transaction.id
        )

      blocks =
        Map.new(start_block..end_block, fn block_number ->
          block = insert(:block, number: block_number)
          insert(:arbitrum_batch_block, batch_number: batch.number, block_number: block_number)

          {block_number, block}
        end)

      %{batch: batch, blocks: blocks}
    end

    defp rollup_block_hash(%{blocks: blocks}, block_number) do
      to_string(blocks[block_number].hash)
    end

    # Inserts a lifecycle transaction standing for a confirmation included in the
    # given parent chain block.
    defp insert_confirmation(l1_block_number, timestamp \\ @confirmation_l1_timestamp - 1000) do
      insert(:arbitrum_lifecycle_transaction,
        block_number: l1_block_number,
        timestamp: DateTime.from_unix!(timestamp)
      )
    end

    # Links the given rollup blocks to the given confirmation, as an already
    # processed confirmation would have done.
    defp mark_confirmed(block_numbers, confirmation) do
      Repo.update_all(
        from(rollup_block in BatchBlock, where: rollup_block.block_number in ^Enum.to_list(block_numbers)),
        set: [confirmation_id: confirmation.id]
      )
    end

    defp confirmed_blocks(confirmation) do
      Repo.all(
        from(rollup_block in BatchBlock,
          where: rollup_block.confirmation_id == ^confirmation.id,
          order_by: rollup_block.block_number,
          select: rollup_block.block_number
        )
      )
    end

    defp unconfirmed_blocks do
      Repo.all(
        from(rollup_block in BatchBlock,
          where: is_nil(rollup_block.confirmation_id),
          order_by: rollup_block.block_number,
          select: rollup_block.block_number
        )
      )
    end

    # Inserts an L2-to-L1 message which was sent in the given rollup block and is
    # waiting for a confirmation.
    defp insert_sent_message_from_l2(rollup_block_number) do
      insert(:arbitrum_message,
        direction: :from_l2,
        status: :sent,
        originating_transaction_block_number: rollup_block_number,
        completion_transaction_hash: nil
      )
    end

    defp message_status(message) do
      Repo.get_by!(Message, direction: :from_l2, message_id: message.message_id).status
    end

    # Builds a raw `SendRootUpdated` event log as it arrives from an `eth_getLogs`
    # JSON-RPC response. The hash of the top confirmed rollup block is the third
    # topic; the second topic (the send root) is not used by the discovery.
    defp build_send_root_updated_log(rollup_block_hash, l1_transaction_hash, l1_block_number) do
      %{
        "address" => @outbox_address,
        "blockHash" => "0x" <> String.duplicate("0", 64),
        "blockNumber" => integer_to_quantity(l1_block_number),
        "data" => "0x",
        "logIndex" => "0x0",
        "removed" => false,
        "topics" => [
          ArbitrumEvents.send_root_updated(),
          "0x" <> String.duplicate("1", 64),
          rollup_block_hash
        ],
        "transactionHash" => l1_transaction_hash,
        "transactionIndex" => "0x0"
      }
    end

    # Mocks both request shapes the discovery issues: the single `eth_getLogs`
    # requests (one per scanned parent chain range) and the batched
    # `eth_getBlockByNumber` request fetching the timestamps of the parent chain
    # blocks holding the confirmations. One closure with two clauses dispatches on
    # the shape of each call, so the two request kinds do not have to be
    # interleaved in the order `expect/4` queues them.
    #
    # A parent chain range absent from `get_logs_responses` raises `KeyError`, so
    # an unexpected range fails the test loudly instead of being silently answered
    # with no logs. Every `eth_getLogs` range is also sent to the calling test
    # process - the whole call path runs synchronously in it - to be drained with
    # `drain_get_logs_ranges/0` afterwards.
    defp expect_rpc(get_logs_responses, l1_blocks_to_timestamps) do
      test_pid = self()

      expect(EthereumJSONRPC.Mox, :json_rpc, map_size(get_logs_responses) + 1, fn
        %{method: "eth_getLogs", params: [%{fromBlock: from_block_quantity, toBlock: to_block_quantity}]}, _options ->
          from_block = quantity_to_integer(from_block_quantity)
          to_block = quantity_to_integer(to_block_quantity)
          send(test_pid, {:eth_get_logs_range, from_block, to_block})

          {:ok, Map.fetch!(get_logs_responses, {from_block, to_block})}

        requests, _options when is_list(requests) ->
          responses =
            Enum.map(requests, fn %{id: id, method: "eth_getBlockByNumber", params: [block_quantity, false]} ->
              timestamp = Map.fetch!(l1_blocks_to_timestamps, quantity_to_integer(block_quantity))

              %{
                id: id,
                jsonrpc: "2.0",
                result: %{"number" => block_quantity, "timestamp" => integer_to_quantity(timestamp)}
              }
            end)

          {:ok, responses}
      end)
    end

    defp drain_get_logs_ranges do
      receive do
        {:eth_get_logs_range, from_block, to_block} -> [{from_block, to_block} | drain_get_logs_ranges()]
      after
        0 -> []
      end
    end
  end
end
