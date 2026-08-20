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

    @bridge_address "0xa723c008e76e379c55599d2e4d93879beafda79"

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
    defp expect_rpc(get_logs_responses, transaction_responses \\ %{}) do
      test_pid = self()
      total_calls = map_size(get_logs_responses) + map_size(transaction_responses)

      expect(EthereumJSONRPC.Mox, :json_rpc, total_calls, fn
        %{method: "eth_getLogs", params: [%{fromBlock: from_block_quantity, toBlock: to_block_quantity}]}, _options ->
          from_block = quantity_to_integer(from_block_quantity)
          to_block = quantity_to_integer(to_block_quantity)
          send(test_pid, {:eth_get_logs_range, from_block, to_block})

          {:ok, Map.get(get_logs_responses, {from_block, to_block}, [])}

        [%{id: 0, jsonrpc: "2.0", method: "eth_getTransactionByHash", params: [transaction_hash]}], _options ->
          from_address = Map.fetch!(transaction_responses, transaction_hash)

          {:ok, [%{id: 0, jsonrpc: "2.0", result: %{"hash" => transaction_hash, "from" => from_address}}]}
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

        insert(:arbitrum_message,
          message_id: 20,
          originator_address: nil,
          originating_transaction_hash: nil,
          origination_timestamp: nil,
          originating_transaction_block_number: nil,
          status: :relayed
        )

        expect_rpc(%{
          {100, 109} => [],
          {110, 119} => [],
          {120, 129} => [],
          {130, 135} => []
        })

        state = build_state(json_rpc_named_arguments, end_message_id: 20, rpc_block_range: 10)

        assert {:ok, _updated_state} = NewMessagesToL2.check_missing_origination(state)

        assert Enum.sort(drain_get_logs_ranges()) == [{100, 109}, {110, 119}, {120, 129}, {130, 135}]
      end

      test "issues exactly one request when the gap does not exceed l1_rpc_block_range", %{
        json_rpc_named_arguments: json_rpc_named_arguments
      } do
        insert(:arbitrum_message, message_id: 40, originating_transaction_block_number: 200)
        insert(:arbitrum_message, message_id: 42, originating_transaction_block_number: 205)

        insert(:arbitrum_message,
          message_id: 41,
          originator_address: nil,
          originating_transaction_hash: nil,
          origination_timestamp: nil,
          originating_transaction_block_number: nil,
          status: :relayed
        )

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

        insert(:arbitrum_message,
          message_id: 51,
          originator_address: nil,
          originating_transaction_hash: nil,
          origination_timestamp: nil,
          originating_transaction_block_number: nil,
          status: :relayed
        )

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

        insert(:arbitrum_message,
          message_id: 61,
          originator_address: nil,
          originating_transaction_hash: nil,
          origination_timestamp: nil,
          originating_transaction_block_number: nil,
          completion_transaction_hash: completion_transaction_hash,
          status: :relayed
        )

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

        assert Enum.sort(drain_get_logs_ranges()) == [{400, 409}, {410, 419}, {420, 429}, {430, 435}]

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

        insert(:arbitrum_message,
          message_id: 71,
          originator_address: nil,
          originating_transaction_hash: nil,
          origination_timestamp: nil,
          originating_transaction_block_number: nil,
          status: :relayed
        )

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

        insert(:arbitrum_message,
          message_id: 81,
          originator_address: nil,
          originating_transaction_hash: nil,
          origination_timestamp: nil,
          originating_transaction_block_number: nil,
          status: :relayed
        )

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
    end
  end
end
