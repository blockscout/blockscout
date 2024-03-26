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
  def filter_l1_to_l2_messages(transactions, report \\ true) do
    messages =
      transactions
      |> Enum.filter(fn tx ->
        tx[:request_id] != nil
      end)
      |> handle_filtered_l1_to_l2_messages()

    if report && not (messages == []) do
      Logger.info("#{length(messages)} completions of L1-to-L2 messages will be imported")
    end

    messages
  end

  @doc """
  TBD
  """
  def filter_l2_to_l1_messages(logs) do
    arbsys_contract = Application.get_env(:indexer, __MODULE__)[:arbsys_contract]

    filtered_logs =
      logs
      |> Enum.filter(fn event ->
        event.address_hash == arbsys_contract and event.first_topic == Db.l2_to_l1_event()
      end)

    handle_filtered_l2_to_l1_messages(filtered_logs)
  end

  def handle_filtered_l1_to_l2_messages([]) do
    []
  end

  def handle_filtered_l1_to_l2_messages(filtered_txs) do
    filtered_txs
    |> Enum.map(fn tx ->
      Logger.debug("L1 to L2 message #{tx.hash} found with the type #{tx.type}")

      %{direction: :to_l2, message_id: tx.request_id, completion_tx_hash: tx.hash, status: :relayed}
      |> complete_to_params()
    end)
  end

  def handle_filtered_l2_to_l1_messages([]) do
    []
  end

  def handle_filtered_l2_to_l1_messages(filtered_logs) do
    # Get values before the loop parsing the events to reduce number of DB requests
    highest_committed_block = Db.highest_committed_block(-1)
    highest_confirmed_block = Db.highest_confirmed_block(-1)

    messages_map =
      filtered_logs
      |> Enum.reduce(%{}, fn event, messages_acc ->
        Logger.debug("L2 to L1 message #{event.transaction_hash} found")

        {message_id, caller, blocknum, timestamp} = l2_to_l1_event_parse(event)

        message =
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

        Map.put(
          messages_acc,
          message_id,
          message
        )
      end)

    Logger.info("Origins of #{length(Map.values(messages_map))} L2-to-L1 messages will be imported")

    # This is required only for the case when l2-to-l1 messages
    # are found by block catchup fetcher
    messages_map
    |> find_and_update_executed_messages()
    |> Map.values()
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

  defp find_and_update_executed_messages(messages) do
    messages
    |> Map.keys()
    |> Db.l1_executions()
    |> Enum.reduce(messages, fn execution, messages_acc ->
      message =
        messages_acc
        |> Map.get(execution.message_id)
        |> Map.put(:completion_tx_hash, execution.execution_transaction.hash.bytes)
        |> Map.put(:status, :relayed)

      Map.put(messages_acc, execution.message_id, message)
    end)
  end
end
