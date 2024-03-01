defmodule Indexer.Fetcher.Arbitrum.Workers.NewL1Executions do
  @moduledoc """
  TBD
  """

  import EthereumJSONRPC,
    only: [quantity_to_integer: 1]

  alias EthereumJSONRPC.Block.ByNumber, as: BlockByNumber

  import Explorer.Helper, only: [decode_data: 2]

  alias Indexer.Fetcher.Arbitrum.Utils.Helper, as: ArbitrumHelper
  alias Indexer.Fetcher.Arbitrum.Utils.{Db, Rpc}
  alias Indexer.Helper, as: IndexerHelper

  alias Explorer.Chain

  require Logger

  # keccak256("OutBoxTransactionExecuted(address,address,uint256,uint256)")
  @outbox_transaction_executed_event "0x20af7f3bbfe38132b8900ae295cd9c8d1914be7052d061a511f3f728dab18964"
  @outbox_transaction_executed_unindexed_params [{:uint, 256}]

  defp get_logs_for_new_executions(start_block, end_block, outbox_address, json_rpc_named_arguments)
       when start_block <= end_block do
    {:ok, logs} =
      IndexerHelper.get_logs(
        start_block,
        end_block,
        outbox_address,
        [@outbox_transaction_executed_event],
        json_rpc_named_arguments
      )

    if length(logs) > 0 do
      Logger.info("Found #{length(logs)} OutBoxTransactionExecuted logs")
    end

    logs
  end

  defp outbox_transaction_executed_event_parse(event) do
    [transaction_index] = decode_data(event["data"], @outbox_transaction_executed_unindexed_params)

    transaction_index
  end

  defp parse_logs_for_new_executions(logs) do
    {executions, lifecycle_txs, blocks_requests} =
      logs
      |> Enum.reduce({[], %{}, %{}}, fn event, {executions, lifecycle_txs, blocks_requests} ->
        msg_id = outbox_transaction_executed_event_parse(event)

        l1_tx_hash_raw = event["transactionHash"]
        l1_tx_hash = Rpc.strhash_to_byteshash(l1_tx_hash_raw)
        l1_blk_num = quantity_to_integer(event["blockNumber"])

        updated_executions = [
          %{
            message_id: msg_id,
            execution_tx_hash: l1_tx_hash
          }
          | executions
        ]

        updated_lifecycle_txs =
          Map.put(
            lifecycle_txs,
            l1_tx_hash,
            %{hash: l1_tx_hash, block: l1_blk_num}
          )

        updated_blocks_requests =
          Map.put(
            blocks_requests,
            l1_blk_num,
            BlockByNumber.request(%{id: 0, number: l1_blk_num}, false, true)
          )

        Logger.info("Execution for L2 message ##{msg_id} found in #{l1_tx_hash_raw}")

        {updated_executions, updated_lifecycle_txs, updated_blocks_requests}
      end)

    {executions, lifecycle_txs, Map.values(blocks_requests)}
  end

  defp get_executions_from_logs(
         logs,
         %{
           json_rpc_named_arguments: json_rpc_named_arguments,
           chunk_size: chunk_size,
           track_finalization: track_finalization?
         } = _l1_rpc_config
       ) do
    {basics_executions, basic_lifecycle_txs, blocks_requests} = parse_logs_for_new_executions(logs)

    blocks_to_ts = Rpc.execute_blocks_requests_and_get_ts(blocks_requests, json_rpc_named_arguments, chunk_size)

    lifecycle_txs =
      basic_lifecycle_txs
      |> ArbitrumHelper.extend_lifecycle_txs_with_ts_and_status(blocks_to_ts, track_finalization?)
      |> Db.get_indices_for_l1_transactions()

    executions =
      basics_executions
      |> Enum.reduce([], fn execution, updated_executions ->
        updated =
          execution
          |> Map.put(:execution_id, lifecycle_txs[execution.execution_tx_hash].id)
          |> Map.drop([:execution_tx_hash])

        [updated | updated_executions]
      end)

    {Map.values(lifecycle_txs), executions}
  end

  defp get_relayed_messages(block_number) do
    confirmed_messages = Db.confirmed_l2_to_l1_messages(block_number)

    if Enum.empty?(confirmed_messages) do
      []
    else
      Logger.info("Identified #{length(confirmed_messages)} l2-to-l1 messages already confirmed but not completed")

      messages_map =
        confirmed_messages
        |> Enum.reduce(%{}, fn msg, acc ->
          Map.put(acc, msg.message_id, msg)
        end)

      messages_map
      |> Map.keys()
      |> Db.l1_executions()
      |> Enum.map(fn execution ->
        messages_map
        |> Map.get(execution.message_id)
        |> Map.put(:completion_tx_hash, execution.execution_transaction.hash.bytes)
        |> Map.put(:status, :relayed)
      end)
    end
  end

  @doc """
  TBD
  """
  def discover(outbox_address, start_block, end_block, l1_rpc_config) do
    logs =
      get_logs_for_new_executions(
        start_block,
        end_block,
        outbox_address,
        l1_rpc_config.json_rpc_named_arguments
      )

    {lifecycle_txs, executions} = get_executions_from_logs(logs, l1_rpc_config)

    {:ok, _} =
      Chain.import(%{
        arbitrum_lifecycle_transactions: %{params: lifecycle_txs},
        arbitrum_l1_executions: %{params: executions},
        timeout: :infinity
      })

    messages = get_relayed_messages(end_block)

    unless Enum.empty?(messages) do
      Logger.info("Marking #{length(messages)} l2-to-l1 messages as completed")

      {:ok, _} =
        Chain.import(%{
          arbitrum_messages: %{params: messages},
          timeout: :infinity
        })
    end
  end
end
