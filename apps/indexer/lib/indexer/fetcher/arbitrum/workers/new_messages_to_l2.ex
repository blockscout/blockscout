defmodule Indexer.Fetcher.Arbitrum.Workers.NewMessagesToL2 do
  @moduledoc """
  TBD
  """

  import EthereumJSONRPC,
    only: [quantity_to_integer: 1]

  import Explorer.Helper, only: [decode_data: 2]

  alias Indexer.Fetcher.Arbitrum.Utils.Rpc
  alias Indexer.Helper, as: IndexerHelper

  alias Explorer.Chain

  require Logger

  @types_of_l1_messages_forwarded_to_l2 [3, 7, 9, 12]

  # keccak256("MessageDelivered(uint256,bytes32,address,uint8,address,bytes32,uint256,uint64)")
  @message_delivered_event "0x5e3c1311ea442664e8b1611bfabef659120ea7a0a2cfc0667700bebc69cbffe1"
  @message_delivered_event_unindexed_params [
    :address,
    {:uint, 8},
    :address,
    {:bytes, 32},
    {:uint, 256},
    {:uint, 64}
  ]

  defp get_logs_for_l1_to_l2_messages(start_block, end_block, bridge_address, json_rpc_named_arguments)
       when start_block <= end_block do
    {:ok, logs} =
      IndexerHelper.get_logs(
        start_block,
        end_block,
        bridge_address,
        [@message_delivered_event],
        json_rpc_named_arguments
      )

    if length(logs) > 0 do
      Logger.debug("Found #{length(logs)} MessageDelivered logs")
    end

    logs
  end

  defp message_delivered_event_parse(event) do
    [
      _inbox,
      kind,
      _sender,
      _message_data_hash,
      _base_fee_l1,
      timestamp
    ] = decode_data(event["data"], @message_delivered_event_unindexed_params)

    message_index = quantity_to_integer(Enum.at(event["topics"], 1))

    {message_index, kind, Timex.from_unix(timestamp)}
  end

  defp parse_logs_for_l1_to_l2_messages(logs) do
    {messages, txs_requests} =
      logs
      |> Enum.reduce({[], %{}}, fn event, {messages, txs_requests} ->
        {msg_id, type, ts} = message_delivered_event_parse(event)

        if type in @types_of_l1_messages_forwarded_to_l2 do
          tx_hash = event["transactionHash"]
          blk_num = quantity_to_integer(event["blockNumber"])

          updated_messages = [
            %{
              direction: :to_l2,
              message_id: msg_id,
              originating_tx_hash: tx_hash,
              origination_timestamp: ts,
              originating_tx_blocknum: blk_num
            }
            | messages
          ]

          updated_txs_requests =
            Map.put(
              txs_requests,
              tx_hash,
              Rpc.transaction_by_hash_request(%{id: 0, hash: tx_hash})
            )

          Logger.debug("L1 to L2 message #{tx_hash} found with the type #{type}")

          {updated_messages, updated_txs_requests}
        else
          {messages, txs_requests}
        end
      end)

    {messages, Map.values(txs_requests)}
  end

  defp get_messages_from_logs(logs, json_rpc_named_arguments, chunk_size) do
    {messages, txs_requests} = parse_logs_for_l1_to_l2_messages(logs)

    txs_to_from = Rpc.execute_transactions_requests_and_get_from(txs_requests, json_rpc_named_arguments, chunk_size)

    Enum.map(messages, fn msg ->
      Map.merge(msg, %{
        originator_address: txs_to_from[msg.originating_tx_hash],
        status: :initiated
      })
    end)
  end

  @doc """
  TBD
  """
  def discover(bridge_address, start_block, end_block, json_rpc_named_argument, chunk_size) do
    logs =
      get_logs_for_l1_to_l2_messages(
        start_block,
        end_block,
        bridge_address,
        json_rpc_named_argument
      )

    messages = get_messages_from_logs(logs, json_rpc_named_argument, chunk_size)

    unless messages == [] do
      Logger.info("Origins of #{length(messages)} L1-to-L2 messages will be imported")
    end

    {:ok, _} =
      Chain.import(%{
        arbitrum_messages: %{params: messages},
        timeout: :infinity
      })
  end
end
