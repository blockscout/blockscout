# SPDX-License-Identifier: LicenseRef-Blockscout
if Application.get_env(:explorer, :chain_type) == :arbitrum do
  defmodule Indexer.Fetcher.Arbitrum.Workers.NewMessagesToL2Test do
    use EthereumJSONRPC.Case, async: false
    use Explorer.DataCase

    import EthereumJSONRPC, only: [quantity_to_integer: 1, integer_to_quantity: 1]
    import Mox

    alias ABI.TypeEncoder
    alias EthereumJSONRPC.Arbitrum.Constants.Events, as: ArbitrumEvents
    alias Explorer.Chain.Arbitrum.Message, as: ArbitrumMessage
    alias Explorer.Repo
    alias Indexer.Fetcher.Arbitrum.Workers.NewMessagesToL2

    @bridge_address "0xa723c008e76e379c55599d2e4d93879beafda790"

    setup :verify_on_exit!

    setup %{json_rpc_named_arguments: json_rpc_named_arguments} do
      mocked_json_rpc_named_arguments = Keyword.put(json_rpc_named_arguments, :transport, EthereumJSONRPC.Mox)

      %{json_rpc_named_arguments: mocked_json_rpc_named_arguments}
    end

    # Builds the fetcher state accepted by `check_missing_origination/1`.
    #
    # `end_message_id` and `missed_message_ids_range` are chosen so that the
    # message-ID range checked by `check_missing_origination/1` always covers
    # `end_message_id` itself, keeping every scenario's setup self-contained.
    defp build_state(json_rpc_named_arguments, opts) do
      end_message_id = Keyword.fetch!(opts, :end_message_id)
      rpc_block_range = Keyword.fetch!(opts, :rpc_block_range)

      %{
        config: %{
          json_l1_rpc_named_arguments: json_rpc_named_arguments,
          l1_rpc_chunk_size: 50,
          l1_rpc_block_range: rpc_block_range,
          l1_bridge_address: @bridge_address,
          l1_rollup_init_block: 0,
          missed_message_ids_range: 1000
        },
        task_data: %{
          check_missing_origination: %{
            end_message_id: end_message_id,
            earliest_discovered_message_id: 0,
            safe_l1_block: 999_999_999
          }
        },
        completed_tasks: %{}
      }
    end

    # Inserts a `:to_l2` message that has completion information but lacks all
    # four origination fields - the shape selected by
    # `messages_to_l2_completed_but_originating_info_missed/2`. The factory
    # already defaults `status` to `:relayed`; `opts` extends or overrides the
    # attributes (e.g. `completion_transaction_hash`).
    defp insert_message_missing_origination(message_id, opts \\ []) do
      insert(
        :arbitrum_message,
        Keyword.merge(
          [
            message_id: message_id,
            originator_address: nil,
            originating_transaction_hash: nil,
            origination_timestamp: nil,
            originating_transaction_block_number: nil
          ],
          opts
        )
      )
    end

    # Mocks both the `eth_getLogs` and `eth_getTransactionByHash` requests the
    # discovery loop can issue, in a single `expect/4` with as many clauses as
    # request shapes: since a single chunk's `eth_getTransactionByHash` lookups
    # are interleaved between two chunks' `eth_getLogs` calls, separate `expect`
    # calls (each queued independently in call order, not dispatched by pattern)
    # would need to predict that interleaving; one closure with multiple clauses
    # dispatches purely on each call's own shape instead.
    #
    # Every `eth_getLogs` request's `fromBlock`/`toBlock` (as integers) is also
    # sent to the calling test process; the whole call path runs synchronously
    # in that same process, so the messages land in its mailbox in call order
    # and can be drained with `drain_get_logs_ranges/0` right after.
    #
    # An `eth_getLogs` range absent from `get_logs_responses` raises `KeyError`,
    # so an unexpected chunk boundary fails the test loudly instead of being
    # silently answered with no logs. A transaction hash mapped to `nil` in
    # `transaction_responses` simulates a successful-but-null
    # `eth_getTransactionByHash` response (the transaction is unknown to the
    # node).
    #
    # By default every map entry is expected to be requested exactly once;
    # scenarios that legitimately repeat requests (e.g. re-scanning overlapping
    # ranges for a retried message) pass the exact call count as
    # `expected_calls`.
    defp expect_rpc(get_logs_responses, transaction_responses \\ %{}, expected_calls \\ nil) do
      test_pid = self()
      total_calls = expected_calls || map_size(get_logs_responses) + map_size(transaction_responses)

      expect(EthereumJSONRPC.Mox, :json_rpc, total_calls, fn
        %{method: "eth_getLogs", params: [%{fromBlock: from_block_quantity, toBlock: to_block_quantity}]}, _options ->
          from_block = quantity_to_integer(from_block_quantity)
          to_block = quantity_to_integer(to_block_quantity)
          send(test_pid, {:eth_get_logs_range, from_block, to_block})

          {:ok, Map.fetch!(get_logs_responses, {from_block, to_block})}

        [%{id: 0, jsonrpc: "2.0", method: "eth_getTransactionByHash", params: [transaction_hash]}], _options ->
          case Map.fetch!(transaction_responses, transaction_hash) do
            nil ->
              {:ok, [%{id: 0, jsonrpc: "2.0", result: nil}]}

            from_address ->
              {:ok, [%{id: 0, jsonrpc: "2.0", result: %{"hash" => transaction_hash, "from" => from_address}}]}
          end
      end)
    end

    defp drain_get_logs_ranges do
      receive do
        {:eth_get_logs_range, from_block, to_block} -> [{from_block, to_block} | drain_get_logs_ranges()]
      after
        0 -> []
      end
    end

    # Builds a raw `MessageDelivered` event log (as it would arrive from an
    # `eth_getLogs` JSON-RPC response) for the given message ID, L1 block number,
    # originating transaction hash, and unix timestamp.
    defp build_message_delivered_log(message_id, block_number, transaction_hash, timestamp) do
      data =
        "0x" <>
          ([<<0::160>>, 3, <<0::160>>, <<0::256>>, 0, timestamp]
           |> TypeEncoder.encode(%ABI.FunctionSelector{
             function: nil,
             types: ArbitrumEvents.message_delivered_unindexed_params()
           })
           |> Base.encode16(case: :lower))

      message_id_topic =
        "0x" <>
          (message_id
           |> Integer.to_string(16)
           |> String.downcase()
           |> String.pad_leading(64, "0"))

      %{
        "address" => @bridge_address,
        "blockHash" => "0x" <> String.duplicate("0", 64),
        "blockNumber" => integer_to_quantity(block_number),
        "data" => data,
        "logIndex" => "0x0",
        "removed" => false,
        "topics" => [ArbitrumEvents.message_delivered(), message_id_topic],
        "transactionHash" => transaction_hash,
        "transactionIndex" => "0x0"
      }
    end

    describe "check_missing_origination/1" do
      test "splits a gap wider than l1_rpc_block_range into exact, contiguous, non-overlapping chunks (regression)",
           %{json_rpc_named_arguments: json_rpc_named_arguments} do
        insert(:arbitrum_message, message_id: 10, originating_transaction_block_number: 100)
        insert(:arbitrum_message, message_id: 30, originating_transaction_block_number: 135)

        insert_message_missing_origination(20)

        expect_rpc(%{
          {100, 109} => [],
          {110, 119} => [],
          {120, 129} => [],
          {130, 135} => []
        })

        state = build_state(json_rpc_named_arguments, end_message_id: 20, rpc_block_range: 10)

        assert {:ok, _updated_state} = NewMessagesToL2.check_missing_origination(state)

        assert drain_get_logs_ranges() == [{100, 109}, {110, 119}, {120, 129}, {130, 135}]
      end

      test "issues exactly one request when the gap does not exceed l1_rpc_block_range", %{
        json_rpc_named_arguments: json_rpc_named_arguments
      } do
        insert(:arbitrum_message, message_id: 40, originating_transaction_block_number: 200)
        insert(:arbitrum_message, message_id: 42, originating_transaction_block_number: 205)

        insert_message_missing_origination(41)

        expect_rpc(%{{200, 205} => []})

        state = build_state(json_rpc_named_arguments, end_message_id: 41, rpc_block_range: 10)

        assert {:ok, _updated_state} = NewMessagesToL2.check_missing_origination(state)

        assert drain_get_logs_ranges() == [{200, 205}]
      end

      test "issues exactly one request for a single-block range", %{
        json_rpc_named_arguments: json_rpc_named_arguments
      } do
        insert(:arbitrum_message, message_id: 50, originating_transaction_block_number: 300)
        insert(:arbitrum_message, message_id: 52, originating_transaction_block_number: 300)

        insert_message_missing_origination(51)

        expect_rpc(%{{300, 300} => []})

        state = build_state(json_rpc_named_arguments, end_message_id: 51, rpc_block_range: 10)

        assert {:ok, _updated_state} = NewMessagesToL2.check_missing_origination(state)

        assert drain_get_logs_ranges() == [{300, 300}]
      end

      test "imports a message whose log falls in a later chunk, preserving completion data and :relayed status", %{
        json_rpc_named_arguments: json_rpc_named_arguments
      } do
        insert(:arbitrum_message, message_id: 60, originating_transaction_block_number: 400)
        insert(:arbitrum_message, message_id: 62, originating_transaction_block_number: 435)

        completion_transaction_hash = transaction_hash()

        insert_message_missing_origination(61, completion_transaction_hash: completion_transaction_hash)

        transaction_hash_string = to_string(transaction_hash())
        originator_address_string = to_string(address_hash())
        timestamp = 1_700_000_000

        log = build_message_delivered_log(61, 425, transaction_hash_string, timestamp)

        expect_rpc(
          %{
            {400, 409} => [],
            {410, 419} => [],
            {420, 429} => [log],
            {430, 435} => []
          },
          %{transaction_hash_string => originator_address_string}
        )

        state = build_state(json_rpc_named_arguments, end_message_id: 61, rpc_block_range: 10)

        assert {:ok, _updated_state} = NewMessagesToL2.check_missing_origination(state)

        assert drain_get_logs_ranges() == [{400, 409}, {410, 419}, {420, 429}, {430, 435}]

        message = Repo.get_by(ArbitrumMessage, direction: :to_l2, message_id: 61)

        assert to_string(message.originator_address) == String.downcase(originator_address_string)
        assert to_string(message.originating_transaction_hash) == String.downcase(transaction_hash_string)
        assert DateTime.to_unix(message.origination_timestamp) == timestamp
        assert message.originating_transaction_block_number == 425
        assert to_string(message.completion_transaction_hash) == to_string(completion_transaction_hash)
        assert message.status == :relayed
      end

      test "applies the message-ID filter per chunk, excluding an out-of-bounds neighbour found in another chunk", %{
        json_rpc_named_arguments: json_rpc_named_arguments
      } do
        insert(:arbitrum_message, message_id: 70, originating_transaction_block_number: 500)
        insert(:arbitrum_message, message_id: 72, originating_transaction_block_number: 535)

        insert_message_missing_origination(71)

        neighbour_transaction_hash_string = to_string(transaction_hash())
        neighbour_originator_address_string = to_string(address_hash())
        target_transaction_hash_string = to_string(transaction_hash())
        target_originator_address_string = to_string(address_hash())
        timestamp = 1_700_000_000

        # Out-of-bounds neighbour: shares message ID 72 with the higher bound
        # message, which already has origination information, so it must be
        # filtered out (the filter is exclusive of the bounds).
        neighbour_log = build_message_delivered_log(72, 505, neighbour_transaction_hash_string, timestamp)
        target_log = build_message_delivered_log(71, 525, target_transaction_hash_string, timestamp)

        # Transaction enrichment happens before the ID filter is applied, so both
        # logs' `eth_getTransactionByHash` lookups are issued even though the
        # neighbour is later filtered out.
        expect_rpc(
          %{
            {500, 509} => [neighbour_log],
            {510, 519} => [],
            {520, 529} => [target_log],
            {530, 535} => []
          },
          %{
            neighbour_transaction_hash_string => neighbour_originator_address_string,
            target_transaction_hash_string => target_originator_address_string
          }
        )

        state = build_state(json_rpc_named_arguments, end_message_id: 71, rpc_block_range: 10)

        assert {:ok, _updated_state} = NewMessagesToL2.check_missing_origination(state)

        target_message = Repo.get_by(ArbitrumMessage, direction: :to_l2, message_id: 71)
        assert to_string(target_message.originating_transaction_hash) == String.downcase(target_transaction_hash_string)
        assert target_message.originating_transaction_block_number == 525

        neighbour_message = Repo.get_by(ArbitrumMessage, direction: :to_l2, message_id: 72)
        assert neighbour_message.originating_transaction_block_number == 535
      end

      test "advances the cursor and completion flag as usual when all chunks return no logs", %{
        json_rpc_named_arguments: json_rpc_named_arguments
      } do
        insert(:arbitrum_message, message_id: 80, originating_transaction_block_number: 600)
        insert(:arbitrum_message, message_id: 82, originating_transaction_block_number: 635)

        insert_message_missing_origination(81)

        expect_rpc(%{
          {600, 609} => [],
          {610, 619} => [],
          {620, 629} => [],
          {630, 635} => []
        })

        state = build_state(json_rpc_named_arguments, end_message_id: 81, rpc_block_range: 10)

        assert {:ok, updated_state} = NewMessagesToL2.check_missing_origination(state)

        assert updated_state.task_data.check_missing_origination.end_message_id == -1
        assert updated_state.completed_tasks.check_missing_origination == true

        assert Repo.get_by(ArbitrumMessage, direction: :to_l2, message_id: 81).originating_transaction_block_number ==
                 nil
      end

      test "skips a message already back-filled by the same loop's processing of a higher ID (regression)", %{
        json_rpc_named_arguments: json_rpc_named_arguments
      } do
        insert(:arbitrum_message, message_id: 90, originating_transaction_block_number: 700)
        insert(:arbitrum_message, message_id: 93, originating_transaction_block_number: 735)

        insert_message_missing_origination(91)
        insert_message_missing_origination(92)

        transaction_hash_91_string = to_string(transaction_hash())
        originator_address_91_string = to_string(address_hash())
        transaction_hash_92_string = to_string(transaction_hash())
        originator_address_92_string = to_string(address_hash())
        timestamp = 1_700_000_000

        # Both logs fall within the L1 block range scanned while processing the
        # higher missing message ID (92); the message-ID filter for that scan
        # allows both 91 and 92 through since it is bounded by the indexed
        # neighbours 90 and 93.
        log_91 = build_message_delivered_log(91, 725, transaction_hash_91_string, timestamp)
        log_92 = build_message_delivered_log(92, 715, transaction_hash_92_string, timestamp)

        expect_rpc(
          %{
            {700, 709} => [],
            {710, 719} => [log_92],
            {720, 729} => [log_91],
            {730, 735} => []
          },
          %{
            transaction_hash_91_string => originator_address_91_string,
            transaction_hash_92_string => originator_address_92_string
          }
        )

        state = build_state(json_rpc_named_arguments, end_message_id: 92, rpc_block_range: 10)

        assert {:ok, _updated_state} = NewMessagesToL2.check_missing_origination(state)

        # Only the chunks scanned while processing message ID 92 are observed;
        # processing message ID 91 afterwards issues no `eth_getLogs` request at
        # all because the skip check finds its origination already filled in.
        assert drain_get_logs_ranges() == [{700, 709}, {710, 719}, {720, 729}, {730, 735}]

        message_91 = Repo.get_by(ArbitrumMessage, direction: :to_l2, message_id: 91)
        assert to_string(message_91.originator_address) == String.downcase(originator_address_91_string)
        assert to_string(message_91.originating_transaction_hash) == String.downcase(transaction_hash_91_string)
        assert message_91.originating_transaction_block_number == 725

        message_92 = Repo.get_by(ArbitrumMessage, direction: :to_l2, message_id: 92)
        assert to_string(message_92.originator_address) == String.downcase(originator_address_92_string)
        assert to_string(message_92.originating_transaction_hash) == String.downcase(transaction_hash_92_string)
        assert message_92.originating_transaction_block_number == 715
      end

      test "does not import a message whose originating transaction lookup returns null and retries it in a later iteration (regression)",
           %{json_rpc_named_arguments: json_rpc_named_arguments} do
        insert(:arbitrum_message, message_id: 100, originating_transaction_block_number: 800)
        insert(:arbitrum_message, message_id: 103, originating_transaction_block_number: 835)

        insert_message_missing_origination(101)
        insert_message_missing_origination(102)

        transaction_hash_101_string = to_string(transaction_hash())
        transaction_hash_102_string = to_string(transaction_hash())
        originator_address_102_string = to_string(address_hash())
        timestamp = 1_700_000_000

        log_101 = build_message_delivered_log(101, 815, transaction_hash_101_string, timestamp)
        log_102 = build_message_delivered_log(102, 829, transaction_hash_102_string, timestamp)

        # Message 101's `eth_getTransactionByHash` responds successfully but with
        # a null result (mapped to `nil` below), so its originator address stays
        # unknown. The message must not be imported half-filled while processing
        # message ID 102 - otherwise the skip check (keyed on the originating
        # block number) would consider it done and it would never be re-processed.
        #
        # Processing 102 scans 800..835 (4 chunks, bounded by messages 100 and
        # 103) and imports only 102. Processing 101 afterwards is NOT skipped:
        # it re-scans 800..829 (3 chunks, the higher bound now comes from the
        # just-imported 102) and repeats both transaction lookups (101's log in
        # chunk {810, 819}, 102's log in chunk {820, 829} - the latter is then
        # dropped by the message-ID filter). Hence 7 `eth_getLogs` calls over 4
        # distinct ranges and 4 `eth_getTransactionByHash` calls over 2 hashes,
        # so the expected call count (11) is passed explicitly.
        expect_rpc(
          %{
            {800, 809} => [],
            {810, 819} => [log_101],
            {820, 829} => [log_102],
            {830, 835} => []
          },
          %{
            transaction_hash_101_string => nil,
            transaction_hash_102_string => originator_address_102_string
          },
          11
        )

        state = build_state(json_rpc_named_arguments, end_message_id: 102, rpc_block_range: 10)

        assert {:ok, _updated_state} = NewMessagesToL2.check_missing_origination(state)

        assert drain_get_logs_ranges() == [
                 {800, 809},
                 {810, 819},
                 {820, 829},
                 {830, 835},
                 {800, 809},
                 {810, 819},
                 {820, 829}
               ]

        # Message 101 stays entirely unimported - no half-filled record with the
        # block number set but the originator address empty - so it remains
        # selectable for a retry on a later pass.
        message_101 = Repo.get_by(ArbitrumMessage, direction: :to_l2, message_id: 101)
        assert message_101.originator_address == nil
        assert message_101.originating_transaction_hash == nil
        assert message_101.origination_timestamp == nil
        assert message_101.originating_transaction_block_number == nil
        assert message_101.status == :relayed

        message_102 = Repo.get_by(ArbitrumMessage, direction: :to_l2, message_id: 102)
        assert to_string(message_102.originator_address) == String.downcase(originator_address_102_string)
        assert message_102.originating_transaction_block_number == 829
      end
    end
  end
end
