# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Indexer.Fetcher.Arbitrum.Workers.Confirmations.TestCase do
  # How this test suite is organized
  #
  # The tests describe the scenarios which the discovery of confirmations must
  # handle. They do not describe the branches of its code. One scenario has three
  # parts:
  #   - one state of the database: the indexed rollup blocks, the known lifecycle
  #     transactions, the rows of the table of confirmations, and the cursors
  #   - one set of `SendRootUpdated` events which the parent chain holds
  #   - the result which the discovery must produce: the owner of each rollup
  #     block, the rows of the table, the cursors, and the statuses of the
  #     L2-to-L1 messages
  #
  # The owner of a rollup block is the confirmation with the lowest `top` which is
  # not below the block. A helper reads the owner with the same query as the API.
  #
  # A test gives one log per event. The mock answers each `eth_getLogs` request
  # with the logs of the requested range. Thus a test holds neither the ranges
  # which the discovery reads nor the number of the requests.
  #
  # The `describe` blocks group the scenarios by the unit of the design:
  #   - the events of one window: what the rows and the owners are after one
  #     window of the main process holds a set of events
  #   - the main process: the window, the cursor, and the wait for the backfill
  #   - the backfill process: the window, the cursor, and the stop rules
  #   - the start point: the cursors at the first run
  #   - two units: a window of the main process and then a window of the backfill
  #     process
  #
  # One file holds one `describe` block.
  #
  # A scenario keeps its test even when another test already runs the same
  # branches of the code. The suite must show the whole matrix of the expected
  # states. A missing scenario tells the reader that the discovery does not
  # support that state.
  #
  # The result of the discovery does not depend on the position of an event in
  # the parent chain. Several tests hold the same set of events in different
  # positions: one parent chain block, the normal order, and the inverted order.
  # These tests prove this fact.

  defmacro __using__(_opts) do
    quote do
      use EthereumJSONRPC.Case, async: false
      use Explorer.DataCase

      import EthereumJSONRPC, only: [integer_to_quantity: 1, quantity_to_integer: 1]
      import Mox

      alias EthereumJSONRPC.Arbitrum.Constants.Events, as: ArbitrumEvents
      alias Explorer.Chain.Arbitrum.{L1Execution, LifecycleTransaction, Message, RollupBlockConfirmation}
      alias Explorer.Chain.Arbitrum.Reader.Common, as: ArbitrumReader
      alias Explorer.Chain.Cache.Counters.LastFetchedCounter
      alias Explorer.Repo
      alias Indexer.Fetcher.Arbitrum.Utils.Db.Messages, as: DbMessages
      alias Indexer.Fetcher.Arbitrum.Utils.Db.Settlement, as: DbSettlement
      alias Indexer.Fetcher.Arbitrum.Workers.Confirmations.Tasks

      @outbox_address "0x0b9857ae2d4a3dbe74ffe1d7df045bb7f96e4840"

      # Bound at compile time so that the `eth_getLogs` clauses of the mock can
      # match them: a pattern cannot call a function.
      @send_root_updated_topic ArbitrumEvents.send_root_updated()
      @outbox_transaction_executed_topic ArbitrumEvents.outbox_transaction_executed()

      # The parent chain block in which the rollup starts. The backfill process
      # stops when its cursor reaches this block.
      @l1_rollup_init_block 100

      # The start point of the discovery: the parent chain block of the commitment
      # of the latest batch. The main process reads up from this block, and the
      # backfill process reads down from the block below it. The tests write the
      # cursors of this start point, unless they test the start point itself.
      @start_point 195
      @main_cursor @start_point - 1
      @backfill_cursor @start_point

      # The safe block of the parent chain. One window of the main process reads
      # the parent chain blocks from the start point to this block.
      @safe_l1_block 205

      # The latest block of the parent chain, for the tests with
      # `finalized_confirmations` set to `false`.
      @latest_l1_block 208

      # The size of one `eth_getLogs` request. Wide enough to read one window of
      # each process in one request.
      @logs_block_range 1000

      # With this size, the main process reads the window of the start point in
      # several runs.
      @short_logs_block_range 3

      # The parent chain blocks of the events in the window of the main process.
      # The event of a test with a single event is in `@confirmation_l1_block`.
      # The lower confirmation of a test with two events is usually in an older
      # block, which is `@lower_confirmation_l1_block`. The lowest confirmation of
      # a test with three events is in `@lowest_confirmation_l1_block`.
      @confirmation_l1_block 200
      @lower_confirmation_l1_block 198
      @lowest_confirmation_l1_block 196

      # The parent chain block of an event below the start point. The backfill
      # process finds it.
      @earlier_confirmation_l1_block 150

      # The parent chain block which the database holds for a lifecycle
      # transaction that a re-org moved. It differs from the block of each event.
      @stale_confirmation_l1_block 190

      # The timestamp of the parent chain block 200. The mock gives each block a
      # timestamp 12 seconds after the block below it.
      @confirmation_l1_timestamp 1_700_000_000

      # The lowest-indexed rollup block.
      @rollup_first_block 1

      # The parent chain block from which the instance indexes the parent chain,
      # for the first run of the historical executions discovery without a cursor
      # and without a known execution.
      @l1_start_block 210

      setup :verify_on_exit!

      setup %{json_rpc_named_arguments: json_rpc_named_arguments} do
        mocked_json_rpc_named_arguments = Keyword.put(json_rpc_named_arguments, :transport, EthereumJSONRPC.Mox)

        %{json_rpc_named_arguments: mocked_json_rpc_named_arguments}
      end

      # Builds the state of the fetcher for the tasks of the discovery. The options
      # override the configuration of one test.
      def state(json_rpc_named_arguments, options \\ []) do
        %{
          config: %{
            l1_rpc: %{
              json_rpc_named_arguments: json_rpc_named_arguments,
              logs_block_range: Keyword.get(options, :logs_block_range, @logs_block_range),
              chunk_size: 10,
              track_finalization: true,
              finalized_confirmations: Keyword.get(options, :finalized_confirmations, true)
            },
            rollup_rpc: %{
              json_rpc_named_arguments: json_rpc_named_arguments,
              chunk_size: 10
            },
            l1_outbox_address: @outbox_address,
            l1_rollup_init_block: Keyword.get(options, :l1_rollup_init_block, @l1_rollup_init_block),
            l1_start_block: @l1_start_block,
            rollup_first_block: Keyword.get(options, :rollup_first_block, @rollup_first_block)
          },
          task_data: %{
            new_confirmations: %{cursor: nil},
            historical_confirmations: %{cursor: nil}
          }
        }
      end

      # Runs one window of the main process.
      def run_main(state) do
        {:ok, new_state} = Tasks.check_new(state)
        new_state
      end

      # Runs one window of the backfill process.
      def run_backfill(state) do
        {:ok, new_state} = Tasks.check_historical(state)
        new_state
      end

      # Runs the backfill process and returns the status with the state.
      def run_backfill_with_status(state) do
        Tasks.check_historical(state)
      end

      # Writes the cursors of both processes. An earlier run of the discovery
      # writes the same cursors. By default, the backfill process is complete:
      # its cursor is at `l1_rollup_init_block`. Thus the main process does not
      # wait for it. A test of the wait writes `@backfill_cursor` instead.
      def seed_cursors(main_cursor \\ @main_cursor, backfill_cursor \\ @l1_rollup_init_block) do
        {:ok, _} = LastFetchedCounter.upsert(%{counter_type: "arbitrum_confirmations_main_cursor", value: main_cursor})

        {:ok, _} =
          LastFetchedCounter.upsert(%{counter_type: "arbitrum_confirmations_backfill_cursor", value: backfill_cursor})

        :ok
      end

      def cursor(process), do: DbSettlement.confirmations_cursor(process)

      # Writes the cursor of the historical executions discovery. An earlier run
      # of that discovery writes the same cursor.
      def seed_executions_cursor(cursor) do
        {:ok, _} = LastFetchedCounter.upsert(%{counter_type: "arbitrum_historical_executions_cursor", value: cursor})
        :ok
      end

      def executions_cursor, do: DbMessages.historical_executions_cursor()

      # Inserts the latest batch with its commitment in the given parent chain
      # block. The start point of the discovery is this block. The range of the
      # batch does not hold `@rollup_first_block`, so the batch does not give the
      # lower bound of the historical executions discovery.
      def seed_latest_batch(commitment_l1_block) do
        commitment_transaction = insert(:arbitrum_lifecycle_transaction, block_number: commitment_l1_block)
        insert(:arbitrum_l1_batch, commitment_id: commitment_transaction.id, start_block: 1000, end_block: 1010)
      end

      # Inserts a batch whose range holds the given rollup block, with its
      # commitment in the given parent chain block. The lower bound of the
      # historical executions discovery is this parent chain block, if the rollup
      # block is `@rollup_first_block`.
      def seed_batch_of_rollup_block(rollup_block_number, commitment_l1_block) do
        commitment_transaction = insert(:arbitrum_lifecycle_transaction, block_number: commitment_l1_block)

        insert(:arbitrum_l1_batch,
          commitment_id: commitment_transaction.id,
          start_block: rollup_block_number,
          end_block: rollup_block_number + 10
        )
      end

      # Inserts an execution of the message with the given identifier, in the
      # given parent chain block. An earlier run of the discovery of executions
      # found this execution.
      def insert_execution(message_id, l1_block_number) do
        execution_transaction = insert(:arbitrum_lifecycle_transaction, block_number: l1_block_number)

        Repo.insert!(%L1Execution{message_id: message_id, execution_id: execution_transaction.id})
      end

      # Inserts the rollup blocks of the range. The discovery reads the number of
      # a confirmed block from these blocks. Returns the blocks keyed by number.
      def seed_blocks(range) do
        Map.new(range, fn block_number -> {block_number, insert(:block, number: block_number)} end)
      end

      def rollup_block_hash(blocks, block_number), do: to_string(blocks[block_number].hash)

      # Inserts a lifecycle transaction which stands for a confirmation in the
      # given parent chain block. The discovery knows this transaction already.
      def insert_confirmation(l1_block_number, timestamp \\ @confirmation_l1_timestamp - 1000) do
        insert(:arbitrum_lifecycle_transaction,
          block_number: l1_block_number,
          timestamp: DateTime.from_unix!(timestamp)
        )
      end

      # Inserts a row of the table of confirmations. An earlier run of the
      # discovery writes the same row.
      def insert_row(top, confirmation) do
        insert(:arbitrum_rollup_block_confirmation, top: top, confirmation_id: confirmation.id)
      end

      # The rows of the table of confirmations as pairs of `top` and the hash of
      # the confirmation transaction, in the order of `top`.
      def rows do
        Repo.all(
          from(row in RollupBlockConfirmation,
            join: transaction in assoc(row, :confirmation_transaction),
            order_by: row.top,
            select: {row.top, transaction.hash}
          )
        )
        |> Enum.map(fn {top, hash} -> {top, to_string(hash)} end)
      end

      # The hash of the confirmation transaction of the rollup block, or `nil` if
      # the block is not confirmed. The helper reads the owner with the same query
      # as the API.
      def owner(block_number) do
        case ArbitrumReader.confirmation_transaction_for_rollup_block(block_number, api?: false) do
          nil -> nil
          transaction -> to_string(transaction.hash)
        end
      end

      # The owners of the rollup blocks of the range, keyed by block number.
      def owners(range), do: Map.new(range, fn block_number -> {block_number, owner(block_number)} end)

      # The expected owners when one confirmation owns every block of the range.
      def owned_by(range, confirmation_transaction_hash) do
        Map.new(range, fn block_number -> {block_number, confirmation_transaction_hash} end)
      end

      def lifecycle_transaction(transaction_hash) do
        Repo.get_by(LifecycleTransaction, hash: transaction_hash)
      end

      # Inserts a rollup-to-parent-chain message which the given rollup block sent
      # and which waits for a confirmation.
      def insert_sent_message_from_l2(rollup_block_number) do
        insert(:arbitrum_message,
          direction: :from_l2,
          status: :sent,
          originating_transaction_block_number: rollup_block_number,
          completion_transaction_hash: nil
        )
      end

      # Inserts a rollup-to-parent-chain message with the given identifier, which
      # is confirmed and waits for its execution on the parent chain.
      def insert_confirmed_message_from_l2(message_id) do
        insert(:arbitrum_message,
          direction: :from_l2,
          message_id: message_id,
          status: :confirmed,
          completion_transaction_hash: nil
        )
      end

      # Inserts a rollup-to-parent-chain message which the given rollup block sent
      # and which is not in a committed batch yet.
      def insert_initiated_message_from_l2(rollup_block_number) do
        insert(:arbitrum_message,
          direction: :from_l2,
          status: :initiated,
          originating_transaction_block_number: rollup_block_number,
          completion_transaction_hash: nil
        )
      end

      def message_status(message) do
        Repo.get_by!(Message, direction: :from_l2, message_id: message.message_id).status
      end

      # The hash of the execution transaction of the message, or `nil` if the
      # discovery of executions did not find the execution.
      def execution(message) do
        case Repo.get_by(Message, direction: :from_l2, message_id: message.message_id).completion_transaction_hash do
          nil -> nil
          hash -> to_string(hash)
        end
      end

      # Builds a raw `OutBoxTransactionExecuted` event log, in the shape of an
      # `eth_getLogs` JSON-RPC response. The identifier of the executed message is
      # the data of the event.
      def build_outbox_transaction_executed_log(message_id, l1_transaction_hash, l1_block_number) do
        %{
          "address" => @outbox_address,
          "blockHash" => "0x" <> String.duplicate("0", 64),
          "blockNumber" => integer_to_quantity(l1_block_number),
          "data" => "0x" <> String.pad_leading(Integer.to_string(message_id, 16), 64, "0"),
          "logIndex" => "0x0",
          "removed" => false,
          "topics" => [
            @outbox_transaction_executed_topic,
            "0x" <> String.duplicate("0", 64),
            "0x" <> String.duplicate("0", 64)
          ],
          "transactionHash" => l1_transaction_hash,
          "transactionIndex" => "0x0"
        }
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

      # The logs of one parent chain range. Both ends of the range belong to it.
      def logs_of_range(logs, from_block, to_block) do
        Enum.filter(logs, fn log ->
          l1_block_number = quantity_to_integer(log["blockNumber"])

          l1_block_number >= from_block and l1_block_number <= to_block
        end)
      end

      # The timestamp of a parent chain block.
      def l1_block_timestamp(l1_block_number) do
        @confirmation_l1_timestamp - (@confirmation_l1_block - l1_block_number) * 12
      end

      # Mocks the RPC calls of the discovery. `logs` holds every `SendRootUpdated`
      # log which the parent chain has, and not only the logs of one window. The
      # mock answers each `eth_getLogs` request with the logs of the requested
      # range. Thus a test gives the state of the parent chain, and it gives no
      # range of its own. The order of `logs` is the order of each response.
      #
      # The mock answers five request shapes:
      #   - one `eth_getLogs` request per parent chain range for the
      #     `SendRootUpdated` events
      #   - one `eth_getLogs` request per parent chain range for the
      #     `OutBoxTransactionExecuted` events, for the discovery of executions
      #   - one batched `eth_getBlockByNumber` request with the tag `safe` or
      #     `latest`, for the limits of the window of the main process
      #   - one batched `eth_getBlockByNumber` request for the timestamps of the
      #     parent chain blocks which hold the confirmations
      #   - one `eth_getBlockByHash` request to the rollup RPC node for a rollup
      #     block which is not indexed
      #
      # Options:
      #   - `safe`: the safe block of the parent chain
      #   - `latest`: the latest block of the parent chain
      #   - `rollup_blocks`: a map of the hash of a rollup block which is not
      #     indexed to its number
      #   - `logs_fail?`: when `true`, each `eth_getLogs` request gives an error,
      #     as the transport does when the RPC node does not answer
      #   - `executions`: every `OutBoxTransactionExecuted` log which the parent
      #     chain has
      def expect_parent_chain(logs, options \\ []) do
        safe_block = Keyword.get(options, :safe, @safe_l1_block)
        latest_block = Keyword.get(options, :latest, @latest_l1_block)
        rollup_blocks = Keyword.get(options, :rollup_blocks, %{})
        logs_fail? = Keyword.get(options, :logs_fail?, false)
        executions = Keyword.get(options, :executions, [])

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
            if logs_fail? do
              {:error, "The RPC node does not give the logs"}
            else
              from_block = quantity_to_integer(from_block_quantity)
              to_block = quantity_to_integer(to_block_quantity)

              {:ok, logs_of_range(logs, from_block, to_block)}
            end

          %{
            method: "eth_getLogs",
            params: [
              %{
                fromBlock: from_block_quantity,
                toBlock: to_block_quantity,
                address: @outbox_address,
                topics: [@outbox_transaction_executed_topic]
              }
            ]
          },
          _options ->
            from_block = quantity_to_integer(from_block_quantity)
            to_block = quantity_to_integer(to_block_quantity)

            {:ok, logs_of_range(executions, from_block, to_block)}

          %{method: "eth_getBlockByHash", params: [rollup_block_hash, false]}, _options ->
            case Map.get(rollup_blocks, rollup_block_hash) do
              nil -> {:ok, nil}
              number -> {:ok, %{"number" => integer_to_quantity(number)}}
            end

          requests, _options when is_list(requests) ->
            responses =
              Enum.map(requests, fn %{id: id, method: "eth_getBlockByNumber", params: [block_param, false]} ->
                case block_param do
                  "safe" -> block_by_tag_response(id, safe_block)
                  "latest" -> block_by_tag_response(id, latest_block)
                  block_quantity -> block_timestamp_response(id, block_quantity)
                end
              end)

            {:ok, responses}
        end)
      end

      # Mocks a parent chain that no process reads. Each request fails the test.
      def expect_no_rpc do
        stub(EthereumJSONRPC.Mox, :json_rpc, fn request, _options ->
          flunk("The discovery sent a request, but no request is expected: #{inspect(request)}")
        end)
      end

      defp block_timestamp_response(id, block_quantity) do
        block_number = quantity_to_integer(block_quantity)

        %{
          id: id,
          jsonrpc: "2.0",
          result: %{"number" => block_quantity, "timestamp" => integer_to_quantity(l1_block_timestamp(block_number))}
        }
      end

      # The full shape of a block, because the parser of a block by tag reads all
      # fields of the block.
      defp block_by_tag_response(id, block_number) do
        %{
          id: id,
          jsonrpc: "2.0",
          result: %{
            "difficulty" => "0x0",
            "gasLimit" => "0x0",
            "gasUsed" => "0x0",
            "hash" => "0x29c850324e357f3c0c836d79860c5af55f7b651e5d7ee253c1af1b14908af49c",
            "extraData" => "0x0",
            "logsBloom" => "0x0",
            "miner" => "0x0",
            "number" => integer_to_quantity(block_number),
            "parentHash" => "0x0",
            "receiptsRoot" => "0x0",
            "size" => "0x0",
            "sha3Uncles" => "0x0",
            "stateRoot" => "0x0",
            "timestamp" => "0x0",
            "totalDifficulty" => "0x0",
            "transactions" => [],
            "transactionsRoot" => "0x0",
            "uncles" => []
          }
        }
      end
    end
  end
end
