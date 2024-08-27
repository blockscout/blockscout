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

  import Explorer.Helper, only: [decode_data: 2]

  alias EthereumJSONRPC.Logs
  alias Explorer.Chain
  alias Indexer.Helper, as: IndexerHelper

  # 32-byte signature of the event SentMessage(address indexed sender, address indexed target, uint256 value, uint256 messageNonce, uint256 gasLimit, bytes message)
  @sent_message_event "0x104371f3b442861a2a7b82a070afbbaab748bb13757bf47769e170e37809ec1e"
  @sent_message_event_params [{:uint, 256}, {:uint, 256}, {:uint, 256}, :bytes]

  # 32-byte signature of the event RelayedMessage(bytes32 indexed messageHash)
  @relayed_message_event "0x4641df4a962071e12719d8c8c8e5ac7fc4d97b927346a3d7a335b1f7517e133c"

  @doc """
  Filters the given list of events keeping only `SentMessage` and `RelayedMessage` ones
  emitted by the messenger contract.
  """
  @spec filter_messenger_events(list(), binary()) :: list()
  def filter_messenger_events(events, messenger_contract) do
    Enum.filter(events, fn event ->
      IndexerHelper.address_hash_to_string(event.address_hash, true) == messenger_contract and
        Enum.member?(
          [@sent_message_event, @relayed_message_event],
          IndexerHelper.log_topic_to_string(event.first_topic)
        )
    end)
  end

  @doc """
  Fetches `SentMessage` and `RelayedMessage` events of the messenger contract from an RPC node
  for the given range of blocks.
  """
  @spec get_logs_all({non_neg_integer(), non_neg_integer()}, binary(), list()) :: list()
  def get_logs_all({chunk_start, chunk_end}, messenger_contract, json_rpc_named_arguments) do
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

  @doc """
  Imports the given Scroll messages into database.
  Used by Indexer.Fetcher.Scroll.BridgeL1 and Indexer.Fetcher.Scroll.BridgeL2 fetchers.
  Doesn't return anything.
  """
  @spec import_operations(list()) :: no_return()
  def import_operations(operations) do
    {:ok, _} =
      Chain.import(%{
        scroll_bridge_operations: %{params: operations},
        timeout: :infinity
      })
  end

  @doc """
  Converts the list of Scroll messenger events to the list of operations
  preparing them for importing to the database.
  """
  @spec prepare_operations(
          list(),
          boolean(),
          list() | nil,
          map() | nil
        ) ::
          list()
  def prepare_operations(
        events,
        is_l1,
        json_rpc_named_arguments,
        block_to_timestamp \\ nil
      ) do
    block_to_timestamp =
      if is_nil(block_to_timestamp) do
        # this function is called by the catchup indexer,
        # so here we can use RPC calls as it's not so critical for delays as in realtime
        events
        |> Enum.filter(fn event -> event.first_topic == @sent_message_event end)
        |> blocks_to_timestamps(json_rpc_named_arguments)
      else
        # this function is called in realtime by the transformer,
        # so we don't use RPC calls to avoid delays and fetch token data
        # in a separate fetcher
        block_to_timestamp
      end

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
              |> String.trim_leading("0x")
              |> Base.decode16!(case: :mixed)

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

  defp blocks_to_timestamps(events, json_rpc_named_arguments) do
    events
    |> IndexerHelper.get_blocks_by_events(json_rpc_named_arguments, IndexerHelper.infinite_retries_number())
    |> Enum.reduce(%{}, fn block, acc ->
      block_number = quantity_to_integer(Map.get(block, "number"))
      timestamp = timestamp_to_datetime(Map.get(block, "timestamp"))
      Map.put(acc, block_number, timestamp)
    end)
  end

  defp sent_message_event_parse(event) do
    sender =
      event.second_topic
      |> String.trim_leading("0x")
      |> Base.decode16!(case: :mixed)

    target =
      event.third_topic
      |> String.trim_leading("0x")
      |> Base.decode16!(case: :mixed)

    [
      amount,
      index,
      _gas_limit,
      message
    ] = decode_data(event.data, @sent_message_event_params)

    {sender, target, amount, index, message}
  end

  defp operation_type(first_topic, is_l1) do
    if first_topic == @sent_message_event do
      if is_l1, do: :deposit, else: :withdrawal
    else
      if is_l1, do: :withdrawal, else: :deposit
    end
  end

  defp extend_result(result, _key, value) when is_nil(value), do: result
  defp extend_result(result, key, value) when is_atom(key), do: Map.put(result, key, value)
end
