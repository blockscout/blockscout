defmodule Indexer.Fetcher.Arbitrum.Messaging do
  @moduledoc """
  TBD
  """
  import EthereumJSONRPC,
    only: [
      quantity_to_integer: 1
    ]

  import Explorer.Helper, only: [decode_data: 2]

  alias Indexer.Fetcher.Arbitrum.Utils.Db

  require Logger

  # 32-byte signature of the event L2ToL1Tx(address caller, address indexed destination, uint256 indexed hash, uint256 indexed position, uint256 arbBlockNum, uint256 ethBlockNum, uint256 timestamp, uint256 callvalue, bytes data)
  @l2_to_l1_event "0x3e7aafa77dbf186b7fd488006beff893744caa3c4f6f299e8a709fa2087374fc"
  @l2_to_l1_event_unindexed_params [
    :address,
    {:uint, 256},
    {:uint, 256},
    {:uint, 256},
    {:uint, 256},
    :bytes
  ]

  @doc """
  TBD
  """
  def filter_l1_to_l2_messages(transactions) do
    transactions
    |> Enum.filter(fn tx ->
      tx[:request_id] != nil
    end)
    |> Enum.map(fn tx ->
      Logger.info("L1 to L2 message #{tx.hash} found with the type #{tx.type}")

      %{direction: :to_l2, message_id: tx.request_id, completion_tx_hash: tx.hash, status: :relayed}
      |> complete_to_params()
    end)
  end

  @doc """
  TBD
  """
  def filter_l2_to_l1_messages(logs) do
    filtered_logs =
      logs
      |> Enum.filter(fn event ->
        event.first_topic == @l2_to_l1_event
      end)

    if Enum.empty?(filtered_logs) do
      []
    else
      highest_committed_block =
        case Db.highest_committed_block() do
          nil -> -1
          value -> value
        end

      highest_confirmed_block =
        case Db.highest_confirmed_block() do
          nil -> -1
          value -> value
        end

      filtered_logs
      |> Enum.map(fn event ->
        Logger.info("L2 to L1 message #{event.transaction_hash} found")

        {message_id, caller, blocknum, timestamp} = l2_to_l1_event_parse(event)

        %{
          direction: :from_l2,
          message_id: message_id,
          originator_address: caller,
          originating_tx_hash: event.transaction_hash,
          origination_timestamp: timestamp,
          originating_tx_blocknum: blocknum,
          status: status_l2_to_l1_message(blocknum, highest_committed_block, highest_confirmed_block)
        }
        |> complete_to_params()
      end)
    end
  end

  defp complete_to_params(incomplete) do
    [
      :direction,
      :message_id,
      :originator_address,
      :originating_tx_hash,
      :origination_timestamp,
      :originating_tx_blocknum,
      :completion_tx_hash,
      :status
    ]
    |> Enum.reduce(%{}, fn key, out ->
      Map.put(out, key, Map.get(incomplete, key))
    end)
  end

  defp l2_to_l1_event_parse(event) do
    [
      caller,
      arb_block_num,
      _eth_block_num,
      timestamp,
      _callvalue,
      _data
    ] = decode_data(event.data, @l2_to_l1_event_unindexed_params)

    position = quantity_to_integer(event.fourth_topic)

    {position, caller, arb_block_num, Timex.from_unix(timestamp)}
  end

  defp status_l2_to_l1_message(msg_block, highest_committed_block, highest_confirmed_block) do
    cond do
      highest_confirmed_block >= msg_block -> :confirmed
      highest_committed_block >= msg_block -> :sent
      true -> :initiated
    end
  end
end
