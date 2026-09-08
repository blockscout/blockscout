# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Indexer.Fetcher.Arbitrum.Workers.Confirmations.Discovery.TestCase do
  # How this test suite is organized
  #
  # The tests describe the scenarios which the discovery must handle. They do not
  # describe the branches of its code. One scenario has four parts:
  #   - one state of the database
  #   - one set of `SendRootUpdated` events which the parent chain holds
  #   - the arguments of the run, which set the limits of the search
  #   - the result which the discovery must produce
  #
  # A test gives one log per event. The mock answers each `eth_getLogs` request
  # with the logs of the requested range. Thus a test holds neither the ranges
  # which the discovery reads nor the number of the requests.
  # Those values show how the discovery collects the data, and a change of them
  # keeps a scenario correct. A test of the number of the requests belongs to
  # `Events.get_logs_for_confirmations/5` and to
  # `RollupBlocks.extend_confirmations/3`, which are the functions that make the
  # requests.
  #
  # The `describe` blocks group the scenarios by the set of events:
  #   - no event
  #   - one new confirmation
  #   - one confirmation which the database knows already
  #   - two new confirmations
  #   - a new confirmation together with a known one
  #   - two known confirmations
  #   - three new confirmations
  #
  # One file holds one `describe` block. When a set of events holds many scenarios, a
  # second dimension splits that set into several groups, and each group keeps its own
  # file. The second dimension is the one which the scenarios of that set vary:
  #   - one new confirmation: the walk of the batches, the re-link of the blocks of a
  #     replaced transaction, an incomplete database, a chunked lookup of the
  #     boundary, and a configured first rollup block
  #   - two new confirmations: the pairs which the lookup of the boundary can see, the
  #     pairs of one parent chain block or of the inverted order, and an incomplete
  #     database
  #   - a new confirmation together with a known one: two batches, one batch, and an
  #     incomplete database
  #
  # The group of an incomplete database carries the same name in each of those sets.
  # Thus a reader finds the two-part tests of the postponements by that name.
  #
  # Even when another test already runs the same branches of the code, a scenario
  # keeps its test. There are two reasons:
  #   - the suite must show the whole matrix of the expected states. A missing
  #     scenario tells the reader that the discovery does not support that state.
  #   - a change of the code can break a scenario of two confirmations and keep
  #     the scenario of a single one. Thus one test cannot replace the other.
  #
  # A test which runs no branch of its own carries a remark. The remark names what
  # the test holds and no other test holds.
  #
  # Some scenarios show a defect of the discovery. The test of such a scenario holds
  # the correct result. It carries the tag `@tag skip: "Defect: ..."`, which names
  # the defect. The output of the run shows the test as skipped, but it does not
  # show this name. Thus the tag keeps the name of the defect in one place, and a
  # search for the word "Defect" gives every test of this kind. The correction of
  # the defect removes the tag.
  #
  # The result `:confirmation_missed` tells the historical discovery to examine the
  # same parent chain range again. The discovery of the new confirmations does not
  # read that range again. It gives the range to the historical discovery. Such a
  # result is correct only when a change of the database can give another result for
  # that range. The indexer makes such a change: it writes a batch, or it links a
  # rollup block to its batch. The discovery does not make such a change.
  #
  # Thus a test of a postponement has two parts. The first part gives the result
  # `:confirmation_missed` for the state of the database. The second part makes the
  # change of the indexer, and it examines the same parent chain range again. The
  # second part must give the result `:ok` and the correct confirmations. The group
  # "perform/5 with a new confirmation and an already known one" holds the scenario
  # of a run which keeps a known confirmation. Thus a second part does not repeat
  # that scenario.
  #
  # A loop is a defect of another kind, and its test has another shape. When no
  # change of the database can give another result, the discovery examines the same
  # parent chain range again and again. Such a test keeps the postponement of the
  # first run, which is the current result. Its second part changes nothing in the
  # database, and it requires the result `:ok` for the repeated run. Thus the test
  # fails on the loop, and not on the result of the first run. The correction of
  # the defect gives `:ok` in the first run. Thus the person who removes the tag
  # also removes the assertions of the first part.

  defmacro __using__(_opts) do
    quote do
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

      # Bound at compile time so that the `eth_getLogs` clause of the mock can match
      # it: a pattern cannot call a function.
      @send_root_updated_topic ArbitrumEvents.send_root_updated()

      # One call of `perform/5` reads the logs of this parent chain range. The
      # `SendRootUpdated` event of each test is in the parent chain block 200.
      @discovery_l1_start_block 195
      @discovery_l1_end_block 205
      @confirmation_l1_block 200
      @confirmation_l1_timestamp 1_700_000_000

      # One parent chain range can hold two `SendRootUpdated` events. The lower
      # confirmation confirms the lower rollup blocks. The parent chain usually holds
      # it in an older block than the upper confirmation, and this block is that older
      # block. Two tests hold both events in `@confirmation_l1_block` instead, because
      # one parent chain block can hold two confirmations. The upper confirmation is
      # the confirmation which every test of a single event uses.
      @lower_confirmation_l1_block 198
      @lower_confirmation_l1_timestamp @confirmation_l1_timestamp - 24

      # One parent chain range can also hold three `SendRootUpdated` events. The
      # confirmation of the lowest rollup blocks is in the oldest block of the three.
      @lowest_confirmation_l1_block 196
      @lowest_confirmation_l1_timestamp @confirmation_l1_timestamp - 48

      # This is the parent chain block which the database holds for a confirmation
      # that a re-org moved. This block is less than the parent chain block of each
      # event. Thus the discovery always finds a difference and writes such a
      # transaction again.
      @stale_confirmation_l1_block 190

      # Wide enough to keep every parent chain lookup of the batch walk within one
      # `eth_getLogs` request. One test passes a short range instead, to make the
      # discovery read a lookup in several chunks.
      @logs_block_range 1000

      # With this range the discovery splits the wider lookups of a batch walk into
      # several chunks. It also keeps two confirmations of one run in two different
      # chunks.
      @short_logs_block_range 3

      # The parent chain block of a confirmation which happened before the one under
      # discovery. This block is between the commitments of the batches and the
      # confirmation under discovery, thus the discovery can find that earlier
      # confirmation. The tests of the re-link also put a stale link to this block.
      # That link belongs to a transaction which the parent chain does not hold.
      @earlier_confirmation_l1_block 150

      # The parent chain block of a confirmation which happened after the one under
      # discovery. This block is more than the end block of the discovery range. The
      # historical discovery moves backward, thus the database can know this confirmation
      # before the discovery reaches the one under discovery.
      @later_confirmation_l1_block 210

      # The parent chain blocks of the commitment transactions of the batches. The
      # first one belongs to the batch with the confirmed block. The other ones
      # belong to the batches below it.
      @commitment_l1_block 100
      @previous_commitment_l1_block 90
      @oldest_commitment_l1_block 80

      # The parent chain block of a commitment transaction which is close to the
      # confirmations. A batch with such a commitment has a short lookup range.
      @recent_commitment_l1_block 194

      # The lowest-indexed rollup block. The oldest batch of each test starts here.
      # Thus the discovery cannot move below this block.
      @rollup_first_block 1

      setup :verify_on_exit!

      setup %{json_rpc_named_arguments: json_rpc_named_arguments} do
        mocked_json_rpc_named_arguments = Keyword.put(json_rpc_named_arguments, :transport, EthereumJSONRPC.Mox)

        %{json_rpc_named_arguments: mocked_json_rpc_named_arguments}
      end

      # Runs the discovery over the parent chain range holding the confirmation.
      def discover(
            json_rpc_named_arguments,
            logs_block_range \\ @logs_block_range,
            rollup_first_block \\ @rollup_first_block
          ) do
        Discovery.perform(
          @outbox_address,
          @discovery_l1_start_block,
          @discovery_l1_end_block,
          %{
            json_rpc_named_arguments: json_rpc_named_arguments,
            logs_block_range: logs_block_range,
            chunk_size: 10,
            track_finalization: true
          },
          rollup_first_block
        )
      end

      # Inserts a batch with its commitment transaction and the rollup blocks of that
      # batch. No block of the batch is confirmed (`confirmation_id` is `nil`).
      # Returns the batch together with the blocks, keyed by block number.
      #
      # `unlinked_blocks` names the blocks which stay outside the batch. Such a block
      # is in the database, but no row links it to the batch. If the indexer did not
      # handle the whole batch, the database has this state. The discovery does not
      # find such a block through the batch of that block.
      #
      # `absent_blocks` names the blocks of the range which are not in the database at
      # all: neither the block nor its link to the batch. If the block fetcher did not
      # reach those blocks yet, the database has this state.
      #
      # Note: `arbitrum_l1_batch_factory` inserts a lifecycle transaction of its own
      # before it applies the `commitment_id` override. Thus each call leaves one
      # unused lifecycle transaction in the database. A count of the rows of
      # `LifecycleTransaction` is therefore not a usable assertion in a test which
      # seeds a batch. Find the transaction by its hash instead.
      def seed_batch(start_block, end_block, commitment_l1_block, options \\ []) do
        commitment_transaction = insert(:arbitrum_lifecycle_transaction, block_number: commitment_l1_block)

        batch =
          insert(:arbitrum_l1_batch,
            start_block: start_block,
            end_block: end_block,
            commitment_id: commitment_transaction.id
          )

        unlinked_blocks = Keyword.get(options, :unlinked_blocks, [])
        absent_blocks = Keyword.get(options, :absent_blocks, [])

        blocks =
          start_block..end_block
          |> Enum.reject(&(&1 in absent_blocks))
          |> Map.new(fn block_number ->
            block = insert(:block, number: block_number)

            if block_number not in unlinked_blocks do
              insert(:arbitrum_batch_block, batch_number: batch.number, block_number: block_number)
            end

            {block_number, block}
          end)

        %{batch: batch, blocks: blocks}
      end

      # Inserts a rollup block which is not in the database yet, and links it to the
      # batch of that block. The block gets the given hash, thus a test can build an
      # event which points to a block before the block fetcher reaches it. The block
      # fetcher and the indexer make this change together.
      def insert_block_and_link_to_batch(%{batch: batch}, block_number, block_hash) do
        insert(:block, number: block_number, hash: block_hash)
        insert(:arbitrum_batch_block, batch_number: batch.number, block_number: block_number)
      end

      # Inserts rollup blocks which no batch of the database holds. If the indexer did
      # not handle the batch of those blocks, the database has this state. Returns the
      # blocks in the shape which `seed_batch/4` returns.
      def seed_blocks_without_batch(start_block, end_block) do
        blocks =
          Map.new(start_block..end_block, fn block_number ->
            {block_number, insert(:block, number: block_number)}
          end)

        %{blocks: blocks}
      end

      # Inserts a batch which holds rollup blocks which are in the database already.
      # The indexer makes this change when it handles the batch of those blocks.
      # Returns the batch together with the blocks, in the shape which `seed_batch/4`
      # returns.
      def seed_batch_of_blocks(%{blocks: blocks}, commitment_l1_block) do
        commitment_transaction = insert(:arbitrum_lifecycle_transaction, block_number: commitment_l1_block)
        block_numbers = Map.keys(blocks)

        batch =
          insert(:arbitrum_l1_batch,
            start_block: Enum.min(block_numbers),
            end_block: Enum.max(block_numbers),
            commitment_id: commitment_transaction.id
          )

        Enum.each(block_numbers, &insert(:arbitrum_batch_block, batch_number: batch.number, block_number: &1))

        %{batch: batch, blocks: blocks}
      end

      # Links rollup blocks of the database to their batch. The indexer makes this
      # change when it handles the whole batch.
      def link_blocks_to_batch(%{batch: batch}, block_numbers) do
        Enum.each(block_numbers, &insert(:arbitrum_batch_block, batch_number: batch.number, block_number: &1))
      end

      def rollup_block_hash(%{blocks: blocks}, block_number) do
        to_string(blocks[block_number].hash)
      end

      # Inserts a lifecycle transaction which stands for a confirmation in the given
      # parent chain block.
      def insert_confirmation(l1_block_number, timestamp \\ @confirmation_l1_timestamp - 1000) do
        insert(:arbitrum_lifecycle_transaction,
          block_number: l1_block_number,
          timestamp: DateTime.from_unix!(timestamp)
        )
      end

      # Links the given rollup blocks to the given confirmation. An earlier run of the
      # discovery makes the same links.
      def mark_confirmed(block_numbers, confirmation) do
        Repo.update_all(
          from(rollup_block in BatchBlock, where: rollup_block.block_number in ^Enum.to_list(block_numbers)),
          set: [confirmation_id: confirmation.id]
        )
      end

      def confirmed_blocks(confirmation) do
        Repo.all(
          from(rollup_block in BatchBlock,
            where: rollup_block.confirmation_id == ^confirmation.id,
            order_by: rollup_block.block_number,
            select: rollup_block.block_number
          )
        )
      end

      # Returns the rollup blocks which hold a link to a batch and no link to a
      # confirmation. A rollup block without a batch is not in this list.
      def unconfirmed_blocks do
        Repo.all(
          from(rollup_block in BatchBlock,
            where: is_nil(rollup_block.confirmation_id),
            order_by: rollup_block.block_number,
            select: rollup_block.block_number
          )
        )
      end

      # Inserts an L2-to-L1 message which was sent in the given rollup block and which
      # waits for a confirmation.
      def insert_sent_message_from_l2(rollup_block_number) do
        insert(:arbitrum_message,
          direction: :from_l2,
          status: :sent,
          originating_transaction_block_number: rollup_block_number,
          completion_transaction_hash: nil
        )
      end

      def message_status(message) do
        Repo.get_by!(Message, direction: :from_l2, message_id: message.message_id).status
      end

      # Builds a raw `SendRootUpdated` event log, in the shape of an `eth_getLogs`
      # JSON-RPC response. The hash of the top confirmed rollup block is the third
      # topic. The discovery does not use the second topic, which is the send root.
      # `options` gives a different position to each log of one parent chain block.
      def build_send_root_updated_log(rollup_block_hash, l1_transaction_hash, l1_block_number, options \\ []) do
        %{
          "address" => @outbox_address,
          "blockHash" => "0x" <> String.duplicate("0", 64),
          "blockNumber" => integer_to_quantity(l1_block_number),
          "data" => "0x",
          "logIndex" => integer_to_quantity(Keyword.get(options, :log_index, 0)),
          "removed" => false,
          "topics" => [
            @send_root_updated_topic,
            "0x" <> String.duplicate("1", 64),
            rollup_block_hash
          ],
          "transactionHash" => l1_transaction_hash,
          "transactionIndex" => integer_to_quantity(Keyword.get(options, :transaction_index, 0))
        }
      end

      # Mocks the RPC calls of one discovery run whose parent chain holds a single
      # `SendRootUpdated` event. The event confirms `top_block_hash` in the
      # transaction `confirmation_transaction_hash`.
      def expect_discovery(top_block_hash, confirmation_transaction_hash) do
        expect_discovery_of([
          build_send_root_updated_log(top_block_hash, confirmation_transaction_hash, @confirmation_l1_block)
        ])
      end

      # Mocks the RPC calls of one discovery run. `logs` holds every
      # `SendRootUpdated` log which the parent chain has, and not only the logs of
      # the discovery range. The mock answers each `eth_getLogs` request with the
      # logs of the requested range. Thus a test gives the state of the parent chain,
      # and it gives no range of its own.
      #
      # The order of `logs` is the order of each response. A test which needs a
      # certain order gives that order here.
      def expect_discovery_of(logs) do
        l1_blocks_to_timestamps =
          logs
          |> logs_of_range(@discovery_l1_start_block, @discovery_l1_end_block)
          |> Map.new(fn log ->
            l1_block_number = quantity_to_integer(log["blockNumber"])

            {l1_block_number, l1_block_timestamp(l1_block_number)}
          end)

        expect_rpc(logs, l1_blocks_to_timestamps)
      end

      # The logs of one parent chain range. Both ends of the range belong to it.
      def logs_of_range(logs, from_block, to_block) do
        Enum.filter(logs, fn log ->
          l1_block_number = quantity_to_integer(log["blockNumber"])

          l1_block_number >= from_block and l1_block_number <= to_block
        end)
      end

      # The timestamp of a parent chain block which holds a confirmation.
      def l1_block_timestamp(@lowest_confirmation_l1_block), do: @lowest_confirmation_l1_timestamp
      def l1_block_timestamp(@lower_confirmation_l1_block), do: @lower_confirmation_l1_timestamp
      def l1_block_timestamp(@confirmation_l1_block), do: @confirmation_l1_timestamp

      # Mocks the two request shapes which the discovery makes:
      #   - one `eth_getLogs` request per parent chain range
      #   - one batched `eth_getBlockByNumber` request for the timestamps of the
      #     parent chain blocks which hold the confirmations
      #
      # One closure with two clauses dispatches on the shape of each call.
      #
      # The `eth_getLogs` clause also matches the contract and the event signature.
      # Thus a request for another address or another topic fails the match. The mock
      # does not answer it as a request for the `SendRootUpdated` events of the
      # outbox.
      #
      # The `eth_getLogs` clause answers with the logs of the requested range. Thus a
      # change of the ranges of the walk does not fail the mock. The state of the
      # database stays the only subject of a test.
      def expect_rpc(parent_chain_logs, l1_blocks_to_timestamps) do
        stub(EthereumJSONRPC.Mox, :json_rpc, fn
          %{
            method: "eth_getLogs",
            params: [
              %{
                fromBlock: from_block_quantity,
                toBlock: to_block_quantity,
                address: @outbox_address,
                topics: [@send_root_updated_topic]
              }
            ]
          },
          _options ->
            from_block = quantity_to_integer(from_block_quantity)
            to_block = quantity_to_integer(to_block_quantity)

            {:ok, logs_of_range(parent_chain_logs, from_block, to_block)}

          requests, _options when is_list(requests) ->
            responses =
              Enum.map(requests, fn %{id: id, method: "eth_getBlockByNumber", params: [block_quantity, false]} ->
                block_number = quantity_to_integer(block_quantity)
                timestamp = Map.fetch!(l1_blocks_to_timestamps, block_number)

                %{
                  id: id,
                  jsonrpc: "2.0",
                  result: %{"number" => block_quantity, "timestamp" => integer_to_quantity(timestamp)}
                }
              end)

            {:ok, responses}
        end)
      end
    end
  end
end
