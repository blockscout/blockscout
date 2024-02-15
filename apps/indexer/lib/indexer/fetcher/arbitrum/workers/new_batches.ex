defmodule Indexer.Fetcher.Arbitrum.Workers.NewBatches do
  @moduledoc """
  TBD
  """

  alias ABI.{FunctionSelector, TypeDecoder}

  import EthereumJSONRPC, only: [quantity_to_integer: 1]

  alias Indexer.Fetcher.Arbitrum.Utils.Helper, as: ArbitrumHelper

  alias EthereumJSONRPC.Block.ByNumber, as: BlockByNumber

  alias Indexer.Helper, as: IndexerHelper
  alias Indexer.Fetcher.Arbitrum.Utils.{Db, Rpc}

  alias Explorer.Chain

  require Logger

  # keccak256("SequencerBatchDelivered(uint256,bytes32,bytes32,bytes32,uint256,(uint64,uint64,uint64,uint64),uint8)")
  @message_sequencer_batch_delivered "0x7394f4a19a13c7b92b5bb71033245305946ef78452f7b4986ac1390b5df4ebd7"

  defp get_logs_new_batches(start_block, end_block, sequencer_inbox_address, json_rpc_named_arguments)
       when start_block <= end_block do
    {:ok, logs} =
      IndexerHelper.get_logs(
        start_block,
        end_block,
        sequencer_inbox_address,
        [@message_sequencer_batch_delivered],
        json_rpc_named_arguments
      )

    if length(logs) > 0 do
      Logger.info("Found #{length(logs)} SequencerBatchDelivered logs")
    end

    logs
  end

  defp sequencer_batch_delivered_event_parse(event) do
    [_, batch_sequence_number, before_acc, after_acc] = event["topics"]

    {quantity_to_integer(batch_sequence_number), before_acc, after_acc}
  end

  defp add_sequencer_l2_batch_from_origin_calldata_parse(calldata) do
    "0x8f111f3c" <> encoded_params = calldata

    # addSequencerL2BatchFromOrigin(uint256 sequenceNumber, bytes calldata data, uint256 afterDelayedMessagesRead, address gasRefunder, uint256 prevMessageCount, uint256 newMessageCount)
    [sequence_number, _data, _after_delayed_messages_read, _gas_refunder, prev_message_count, new_message_count] =
      TypeDecoder.decode(
        Base.decode16!(encoded_params, case: :lower),
        %FunctionSelector{
          function: "addSequencerL2BatchFromOrigin",
          types: [
            {:uint, 256},
            :bytes,
            {:uint, 256},
            :address,
            {:uint, 256},
            {:uint, 256}
          ]
        }
      )

    {sequence_number, prev_message_count, new_message_count}
  end

  defp parse_logs_for_new_batches(logs) do
    {batches, txs_requests, blocks_requests} =
      logs
      |> Enum.reduce({%{}, [], %{}}, fn event, {batches, txs_requests, blocks_requests} ->
        {batch_num, before_acc, after_acc} = sequencer_batch_delivered_event_parse(event)

        tx_hash = event["transactionHash"]
        blk_num = quantity_to_integer(event["blockNumber"])

        updated_batches =
          Map.put(
            batches,
            batch_num,
            %{
              number: batch_num,
              before_acc: before_acc,
              after_acc: after_acc,
              tx_hash: tx_hash
            }
          )

        updated_txs_requests = [
          Rpc.transaction_by_hash_request(%{id: 0, hash: tx_hash})
          | txs_requests
        ]

        updated_blocks_requests =
          Map.put(
            blocks_requests,
            blk_num,
            BlockByNumber.request(%{id: 0, number: blk_num}, false, true)
          )

        Logger.info("New batch #{batch_num} found in #{tx_hash}")

        {updated_batches, updated_txs_requests, updated_blocks_requests}
      end)

    {batches, txs_requests, Map.values(blocks_requests)}
  end

  defp get_l1_tx_id_by_hash(l1_txs, hash) do
    l1_txs
    |> Map.get(hash)
    |> Kernel.||(%{id: nil})
    |> Map.get(:id)
  end

  defp get_batches_from_logs(logs, msg_to_block_shift, track_finalization?, json_rpc_named_arguments, chunk_size) do
    {batches, txs_requests, blocks_requests} = parse_logs_for_new_batches(logs)

    blocks_to_ts = Rpc.execute_blocks_requests_and_get_ts(blocks_requests, json_rpc_named_arguments, chunk_size)

    {lifecycle_txs_wo_indices, batches_to_import} =
      txs_requests
      |> ArbitrumHelper.list_to_chunks(chunk_size)
      |> Enum.reduce({%{}, batches}, fn chunk, {l1_txs, updated_batches} ->
        chunk
        # each eth_getTransactionByHash will take time since it returns entire batch
        # in `input` which is heavy because contains dozens of rollup blocks
        |> Rpc.make_chunked_request(json_rpc_named_arguments, "eth_getTransactionByHash")
        |> Enum.reduce({l1_txs, updated_batches}, fn resp, {txs_map, batches_map} ->
          block_num = quantity_to_integer(resp["blockNumber"])
          tx_hash = resp["hash"]

          # Every message is an L2 block
          {batch_num, prev_message_count, new_message_count} =
            add_sequencer_l2_batch_from_origin_calldata_parse(resp["input"])

          updated_batches_map =
            Map.put(
              batches_map,
              batch_num,
              Map.merge(batches_map[batch_num], %{
                start_block: prev_message_count + msg_to_block_shift,
                end_block: new_message_count + msg_to_block_shift - 1
              })
            )

          updated_txs_map =
            Map.put(txs_map, tx_hash, %{
              hash: tx_hash,
              block: block_num,
              timestamp: blocks_to_ts[block_num],
              status:
                if track_finalization? do
                  :unfinalized
                else
                  :finalized
                end
            })

          {updated_txs_map, updated_batches_map}
        end)
      end)

    lifecycle_txs =
      lifecycle_txs_wo_indices
      |> Db.get_indices_for_l1_transactions()

    batches_list_to_import =
      batches_to_import
      |> Map.values()
      |> Enum.reduce([], fn batch, updated_batches_list ->
        [
          # TODO
          batch
          |> Map.put(:commit_id, get_l1_tx_id_by_hash(lifecycle_txs, batch.tx_hash))
          |> Map.put(:tx_count, 0)
          |> Map.drop([:tx_hash])
          | updated_batches_list
        ]
      end)

    {batches_list_to_import, Map.values(lifecycle_txs)}
  end

  @doc """
  TBD
  """
  def discover(
        sequencer_inbox_address,
        start_block,
        end_block,
        messages_to_blocks_shift,
        json_rpc_named_arguments,
        chunk_size,
        track_l1_finalization?
      ) do
    logs =
      get_logs_new_batches(
        start_block,
        end_block,
        sequencer_inbox_address,
        json_rpc_named_arguments
      )

    {batches, lifecycle_txs} =
      get_batches_from_logs(
        logs,
        messages_to_blocks_shift,
        track_l1_finalization?,
        json_rpc_named_arguments,
        chunk_size
      )

    {:ok, _} =
      Chain.import(%{
        arbitrum_lifecycle_transactions: %{params: lifecycle_txs},
        arbitrum_l1_batches: %{params: batches},
        timeout: :infinity
      })
  end
end
