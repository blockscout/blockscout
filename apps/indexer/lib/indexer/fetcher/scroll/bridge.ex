defmodule Indexer.Fetcher.Scroll.Bridge do
  @moduledoc """
  Contains common functions for Indexer.Fetcher.Scroll.Bridge* modules.
  """

  require Logger

  import EthereumJSONRPC,
    only: [
      quantity_to_integer: 1,
      timestamp_to_datetime: 1
    ]

  import Explorer.Helper, only: [decode_data: 2, hash_to_binary: 1]

  alias EthereumJSONRPC.Logs
  alias Explorer.Chain
  alias Explorer.Chain.RollupReorgMonitorQueue
  alias Indexer.Fetcher.Scroll.BridgeL1
  alias Indexer.Helper, as: IndexerHelper

  # 32-byte signature of the event SentMessage(address indexed sender, address indexed target, uint256 value, uint256 messageNonce, uint256 gasLimit, bytes message)
  @sent_message_event "0x104371f3b442861a2a7b82a070afbbaab748bb13757bf47769e170e37809ec1e"
  @sent_message_event_params [{:uint, 256}, {:uint, 256}, {:uint, 256}, :bytes]

  # 32-byte signature of the event RelayedMessage(bytes32 indexed messageHash)
  @relayed_message_event "0x4641df4a962071e12719d8c8c8e5ac7fc4d97b927346a3d7a335b1f7517e133c"

  @doc """
  The main function that scans RPC node for the message logs (events), parses them,
  and imports to the database (scroll_bridge table).

  The function works for both L1 and L2 layers (depending on the `module` parameter).
  It splits a given block range by chunks and scans the messenger contract for the message
  logs (events) for each chunk. The found events are handled and then imported to the
  `scroll_bridge` database table.

  After historical block range is covered, the function switches to realtime mode and
  searches for the message events in every new block. Reorg blocks are taken into account.

  ## Parameters
  - `module`: The module from which the function was called: Indexer.Fetcher.Scroll.BridgeL1 or Indexer.Fetcher.Scroll.BridgeL2.
  - `state`: The state map containing needed data such as messenger contract address and the block range.

  ## Returns
  - {:noreply, state} tuple with the updated block range in the `state` to scan logs in.
  """
  @spec loop(module(), %{
          block_check_interval: non_neg_integer(),
          messenger_contract: binary(),
          json_rpc_named_arguments: EthereumJSONRPC.json_rpc_named_arguments(),
          end_block: non_neg_integer(),
          start_block: non_neg_integer()
        }) ::
          {:noreply,
           %{
             block_check_interval: non_neg_integer(),
             messenger_contract: binary(),
             json_rpc_named_arguments: EthereumJSONRPC.json_rpc_named_arguments(),
             end_block: non_neg_integer(),
             start_block: non_neg_integer()
           }}
  def loop(
        module,
        %{
          block_check_interval: block_check_interval,
          messenger_contract: messenger_contract,
          json_rpc_named_arguments: json_rpc_named_arguments,
          end_block: end_block,
          start_block: start_block
        } = state
      ) do
    {layer, eth_get_logs_range_size_config} =
      if module == BridgeL1 do
        {:L1, :l1_eth_get_logs_range_size}
      else
        {:L2, :l2_eth_get_logs_range_size}
      end

    eth_get_logs_range_size = Application.get_all_env(:indexer)[Indexer.Fetcher.Scroll][eth_get_logs_range_size_config]

    time_before = Timex.now()

    last_written_block =
      start_block..end_block
      |> Enum.chunk_every(eth_get_logs_range_size)
      |> Enum.reduce_while(start_block - 1, fn current_chunk, _ ->
        chunk_start = List.first(current_chunk)
        chunk_end = List.last(current_chunk)

        if chunk_start <= chunk_end do
          IndexerHelper.log_blocks_chunk_handling(chunk_start, chunk_end, start_block, end_block, nil, layer)

          operations =
            {chunk_start, chunk_end}
            |> get_logs_all(messenger_contract, json_rpc_named_arguments)
            |> prepare_operations(layer == :L1, json_rpc_named_arguments)

          import_operations(operations)

          IndexerHelper.log_blocks_chunk_handling(
            chunk_start,
            chunk_end,
            start_block,
            end_block,
            "#{Enum.count(operations)} #{layer} operation(s)",
            layer
          )
        end

        reorg_block = RollupReorgMonitorQueue.reorg_block_pop(module)

        if !is_nil(reorg_block) && reorg_block > 0 do
          # credo:disable-for-next-line Credo.Check.Refactor.Nesting
          if layer == :L1 do
            BridgeL1.reorg_handle(reorg_block)
          end

          {:halt, if(reorg_block <= chunk_end, do: reorg_block - 1, else: chunk_end)}
        else
          {:cont, chunk_end}
        end
      end)

    new_start_block = last_written_block + 1

    {:ok, new_end_block} =
      IndexerHelper.get_block_number_by_tag("latest", json_rpc_named_arguments, IndexerHelper.infinite_retries_number())

    delay =
      if new_end_block == last_written_block do
        # there is no new block, so wait for some time to let the chain issue the new block
        max(block_check_interval - Timex.diff(Timex.now(), time_before, :milliseconds), 0)
      else
        0
      end

    Process.send_after(Process.whereis(module), :continue, delay)

    {:noreply, %{state | start_block: new_start_block, end_block: new_end_block}}
  end

  # Fetches `SentMessage` and `RelayedMessage` events of the messenger contract from an RPC node
  # for the given range of blocks.
  @spec get_logs_all({non_neg_integer(), non_neg_integer()}, binary(), EthereumJSONRPC.json_rpc_named_arguments()) ::
          [%{atom() => any()}]
  defp get_logs_all({chunk_start, chunk_end}, messenger_contract, json_rpc_named_arguments) do
    {:ok, result} =
      IndexerHelper.get_logs(
        chunk_start,
        chunk_end,
        messenger_contract,
        [[@sent_message_event, @relayed_message_event]],
        json_rpc_named_arguments,
        0,
        IndexerHelper.infinite_retries_number()
      )

    Logs.elixir_to_params(result)
  end

  # Imports the given Scroll messages into database.
  # Used by Indexer.Fetcher.Scroll.BridgeL1 and Indexer.Fetcher.Scroll.BridgeL2 fetchers.
  # Doesn't return anything.
  @spec import_operations([Chain.Scroll.Bridge.to_import()]) :: no_return()
  defp import_operations(operations) do
    {:ok, _} =
      Chain.import(%{
        scroll_bridge_operations: %{params: operations},
        timeout: :infinity
      })
  end

  # Converts the list of Scroll messenger events to the list of operations
  # preparing them for importing to the database.
  @spec prepare_operations([%{atom() => any()}], boolean(), EthereumJSONRPC.json_rpc_named_arguments()) :: [
          Chain.Scroll.Bridge.to_import()
        ]
  defp prepare_operations(events, is_l1, json_rpc_named_arguments) do
    block_to_timestamp =
      events
      |> Enum.filter(fn event -> event.first_topic == @sent_message_event end)
      |> blocks_to_timestamps(json_rpc_named_arguments)

    events
    |> Enum.map(fn event ->
      {index, amount, block_number, block_timestamp, message_hash} =
        case event.first_topic do
          @sent_message_event ->
            {
              sender,
              target,
              amount,
              index,
              message
            } = sent_message_event_parse(event)

            block_number = quantity_to_integer(event.block_number)
            block_timestamp = Map.get(block_to_timestamp, block_number)

            operation_encoded =
              ABI.encode("relayMessage(address,address,uint256,uint256,bytes)", [
                sender |> :binary.decode_unsigned(),
                target |> :binary.decode_unsigned(),
                amount,
                index,
                message
              ])

            message_hash =
              "0x" <>
                (operation_encoded
                 |> ExKeccak.hash_256()
                 |> Base.encode16(case: :lower))

            {index, amount, block_number, block_timestamp, message_hash}

          @relayed_message_event ->
            message_hash =
              event.second_topic
              |> hash_to_binary()

            {nil, nil, nil, nil, message_hash}
        end

      result = %{
        type: operation_type(event.first_topic, is_l1),
        message_hash: message_hash
      }

      transaction_hash_field =
        if is_l1 do
          :l1_transaction_hash
        else
          :l2_transaction_hash
        end

      result
      |> extend_result(:index, index)
      |> extend_result(transaction_hash_field, event.transaction_hash)
      |> extend_result(:amount, amount)
      |> extend_result(:block_number, block_number)
      |> extend_result(:block_timestamp, block_timestamp)
    end)
  end

  # Constructs a map defining block timestamps by block numbers (key-value pairs)
  # from the list of events. The keys of the resulting map consist of block numbers,
  # the values are timestamps.
  #
  # ## Parameters
  # - `events`: The list of events based on which the map is constructed.
  # - `json_rpc_named_arguments`: Configuration parameters for the JSON RPC connection.
  #
  # ## Returns
  # - A dictionary associating block timestamps with the their numbers.
  @spec blocks_to_timestamps([%{atom() => any()}], EthereumJSONRPC.json_rpc_named_arguments()) :: %{
          non_neg_integer() => DateTime.t()
        }
  defp blocks_to_timestamps(events, json_rpc_named_arguments) do
    events
    |> IndexerHelper.get_blocks_by_events(json_rpc_named_arguments, IndexerHelper.infinite_retries_number())
    |> Enum.reduce(%{}, fn block, acc ->
      block_number = quantity_to_integer(Map.get(block, "number"))
      timestamp = timestamp_to_datetime(Map.get(block, "timestamp"))
      Map.put(acc, block_number, timestamp)
    end)
  end

  # Parses the `SentMessage` event to retrieve message sender address,
  # target address, amount, index, body. This components are returned
  # in the tuple.
  #
  # ## Parameters
  # - `event`: A map describing the event which needs to be parsed.
  #
  # ## Returns
  # - `{sender, target, amount, index, message}` where
  #   the `sender` is the message sender address,
  #   the `target` is the target address,
  #   the `amount` is the amount of the native token sent within this message,
  #   the `index` is the message numeric index,
  #   the `message` is the message body.
  @spec sent_message_event_parse(%{atom() => any()}) ::
          {binary(), binary(), non_neg_integer(), non_neg_integer(), binary()}
  defp sent_message_event_parse(event) do
    sender = hash_to_binary(event.second_topic)
    target = hash_to_binary(event.third_topic)

    [
      amount,
      index,
      _gas_limit,
      message
    ] = decode_data(event.data, @sent_message_event_params)

    {sender, target, amount, index, message}
  end

  # Determines the type of the bridge operation based on the event and the chain layer (L1 or L2).
  #
  # ## Parameters
  # - `first_topic`: The signature of the event (in 0x-prefixed hex string).
  # - `is_l1`: A boolean flag defining whether the chain layer is L1.
  #
  # ## Returns
  # - :deposit or :withdrawal
  @spec operation_type(binary(), boolean()) :: :deposit | :withdrawal
  defp operation_type(first_topic, is_l1) do
    if first_topic == @sent_message_event do
      if is_l1, do: :deposit, else: :withdrawal
    else
      if is_l1, do: :withdrawal, else: :deposit
    end
  end

  # Extends the resulting map with the key-value pair. Used by the `prepare_operations` function.
  # If the value is `nil`, the key-value pair is not added.
  #
  # ## Parameters
  # - `result`: The resulting map to be extended.
  # - `key`: The key component of the key-value pair.
  # - `value`: The value component of the key-value pair.
  #
  # ## Returns
  # - The extended map.
  @spec extend_result(map(), atom(), any()) :: map()
  defp extend_result(result, _key, value) when is_nil(value), do: result
  defp extend_result(result, key, value) when is_atom(key), do: Map.put(result, key, value)
end
