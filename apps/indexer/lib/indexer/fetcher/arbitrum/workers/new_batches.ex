defmodule Indexer.Fetcher.Arbitrum.Workers.NewBatches do
  @moduledoc """
  TBD
  """

  alias ABI.{FunctionSelector, TypeDecoder}

  import EthereumJSONRPC, only: [quantity_to_integer: 1]

  alias Indexer.Fetcher.Arbitrum.Utils.Helper, as: ArbitrumHelper

  alias EthereumJSONRPC.Block.ByNumber, as: BlockByNumber

  alias Indexer.Helper, as: IndexerHelper
  alias Indexer.Fetcher.Arbitrum.Utils.{Db, Logging, Rpc}

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
    case calldata do
      "0x8f111f3c" <> encoded_params ->
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

      "0x3e5aa082" <> encoded_params ->
        # addSequencerL2BatchFromBlobs(uint256 sequenceNumber, uint256 afterDelayedMessagesRead, address gasRefunder, uint256 prevMessageCount, uint256 newMessageCount)
        [sequence_number, _after_delayed_messages_read, _gas_refunder, prev_message_count, new_message_count] =
          TypeDecoder.decode(
            Base.decode16!(encoded_params, case: :lower),
            %FunctionSelector{
              function: "addSequencerL2BatchFromBlobs",
              types: [
                {:uint, 256},
                {:uint, 256},
                :address,
                {:uint, 256},
                {:uint, 256}
              ]
            }
          )

        {sequence_number, prev_message_count, new_message_count}
    end
  end

  defp parse_logs_to_get_batch_numbers(logs) do
    logs
    |> Enum.map(fn event ->
      {batch_num, _, _} = sequencer_batch_delivered_event_parse(event)
      batch_num
    end)
  end

  defp parse_logs_for_new_batches(logs, existing_batches) do
    {batches, txs_requests, blocks_requests} =
      logs
      |> Enum.reduce({%{}, [], %{}}, fn event, {batches, txs_requests, blocks_requests} ->
        {batch_num, before_acc, after_acc} = sequencer_batch_delivered_event_parse(event)

        tx_hash_raw = event["transactionHash"]
        tx_hash = Rpc.strhash_to_byteshash(tx_hash_raw)
        blk_num = quantity_to_integer(event["blockNumber"])

        if batch_num in existing_batches do
          {batches, txs_requests, blocks_requests}
        else
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
            Rpc.transaction_by_hash_request(%{id: 0, hash: tx_hash_raw})
            | txs_requests
          ]

          updated_blocks_requests =
            Map.put(
              blocks_requests,
              blk_num,
              BlockByNumber.request(%{id: 0, number: blk_num}, false, true)
            )

          Logger.info("New batch #{batch_num} found in #{tx_hash_raw}")

          {updated_batches, updated_txs_requests, updated_blocks_requests}
        end
      end)

    {batches, txs_requests, Map.values(blocks_requests)}
  end

  defp get_l1_tx_id_by_hash(l1_txs, hash) do
    l1_txs
    |> Map.get(hash)
    |> Kernel.||(%{id: nil})
    |> Map.get(:id)
  end

  defp prepare_rollup_block_map_and_transactions_list(json_responses, rollup_blocks, rollup_txs) do
    json_responses
    |> Enum.reduce({rollup_blocks, rollup_txs}, fn resp, {blocks_map, txs_list} ->
      batch_num = resp.id
      blk_hash = resp.result["hash"]
      blk_num = quantity_to_integer(resp.result["number"])

      updated_blocks_map =
        Map.put(
          blocks_map,
          blk_num,
          %{hash: blk_hash, batch_number: batch_num, confirm_id: nil}
        )

      updated_txs_list =
        case resp.result["transactions"] do
          nil ->
            txs_list

          new_txs ->
            Enum.reduce(new_txs, txs_list, fn l2_tx_hash, txs_list ->
              [
                %{hash: l2_tx_hash, batch_number: batch_num, block_hash: blk_hash}
                | txs_list
              ]
            end)
        end

      {updated_blocks_map, updated_txs_list}
    end)
  end

  defp unwrap_rollup_block_ranges(batches) do
    batches
    |> Map.values()
    |> Enum.reduce(%{}, fn batch, b_2_b ->
      batch.start_block..batch.end_block
      |> Enum.reduce(b_2_b, fn block_num, b_2_b_inner ->
        Map.put(b_2_b_inner, block_num, batch.number)
      end)
    end)
  end

  defp get_rollup_blocks_and_txs_from_db(rollup_blocks_numbers, blocks_to_batches) do
    rollup_blocks_numbers
    |> Db.rollup_blocks()
    |> Enum.reduce({%{}, []}, fn block, {blocks_map, txs_list} ->
      batch_num = blocks_to_batches[block.number]
      blk_hash = block.hash.bytes

      updated_txs_list =
        block.transactions
        |> Enum.reduce(txs_list, fn tx, acc ->
          [
            %{hash: tx.hash.bytes, batch_number: batch_num, block_hash: blk_hash}
            | acc
          ]
        end)

      updated_blocks_map =
        blocks_map
        |> Map.put(block.number, %{hash: blk_hash, batch_number: batch_num, confirm_id: nil})

      {updated_blocks_map, updated_txs_list}
    end)
  end

  defp recover_rollup_blocks_and_txs_from_rpc(required_blocks_numbers, found_blocks_numbers, blocks_to_batches, %{
         json_rpc_named_arguments: rollup_json_rpc_named_arguments,
         chunk_size: rollup_chunk_size
       }) do
    missed_blocks = required_blocks_numbers -- found_blocks_numbers
    missed_blocks_length = length(missed_blocks)

    missed_blocks
    |> Enum.sort()
    |> Enum.chunk_every(rollup_chunk_size)
    |> Enum.reduce({%{}, [], 0}, fn chunk, {blocks_map, txs_list, chunks_counter} ->
      Logging.log_details_chunk_handling(
        "Collecting rollup data",
        {"block", "blocks"},
        chunk,
        chunks_counter,
        missed_blocks_length
      )

      requests =
        chunk
        |> Enum.reduce([], fn block_num, requests_list ->
          [
            BlockByNumber.request(
              %{
                id: blocks_to_batches[block_num],
                number: block_num
              },
              false
            )
            | requests_list
          ]
        end)

      {blocks_map_updated, txs_list_updated} =
        requests
        |> Rpc.make_chunked_request_keep_id(rollup_json_rpc_named_arguments, "eth_getBlockByNumber")
        |> prepare_rollup_block_map_and_transactions_list(blocks_map, txs_list)

      {blocks_map_updated, txs_list_updated, chunks_counter + length(chunk)}
    end)
  end

  defp recover_data_if_necessary(
         current_rollup_blocks,
         current_rollup_txs,
         required_blocks_numbers,
         blocks_to_batches,
         rollup_rpc_config
       ) do
    required_blocks_amount = length(required_blocks_numbers)

    found_blocks_numbers = Map.keys(current_rollup_blocks)
    found_blocks_numbers_length = length(found_blocks_numbers)

    if found_blocks_numbers_length != required_blocks_amount do
      Logger.info("Only #{found_blocks_numbers_length} of #{required_blocks_amount} rollup blocks found in DB")

      {recovered_blocks_map, recovered_txs_list, _} =
        recover_rollup_blocks_and_txs_from_rpc(
          required_blocks_numbers,
          found_blocks_numbers,
          blocks_to_batches,
          rollup_rpc_config
        )

      {Map.merge(current_rollup_blocks, recovered_blocks_map), current_rollup_txs ++ recovered_txs_list}
    else
      {current_rollup_blocks, current_rollup_txs}
    end
  end

  defp get_rollup_blocks_and_transactions(
         batches,
         rollup_rpc_config
       ) do
    blocks_to_batches = unwrap_rollup_block_ranges(batches)

    required_blocks_numbers = Map.keys(blocks_to_batches)
    Logger.info("Identified #{length(required_blocks_numbers)} rollup blocks")

    {blocks_to_import_map, txs_to_import_list} =
      get_rollup_blocks_and_txs_from_db(required_blocks_numbers, blocks_to_batches)

    {blocks_to_import, txs_to_import} =
      recover_data_if_necessary(
        blocks_to_import_map,
        txs_to_import_list,
        required_blocks_numbers,
        blocks_to_batches,
        rollup_rpc_config
      )

    Logger.info(
      "Found #{length(Map.keys(blocks_to_import))} rollup blocks and #{length(txs_to_import)} rollup transactions in DB"
    )

    {blocks_to_import, txs_to_import}
  end

  defp execute_tx_requests_parse_txs_calldata(txs_requests, msg_to_block_shift, blocks_to_ts, batches, %{
         json_rpc_named_arguments: json_rpc_named_arguments,
         track_finalization: track_finalization?,
         chunk_size: chunk_size
       }) do
    txs_requests
    |> ArbitrumHelper.list_to_chunks(chunk_size)
    |> Enum.reduce({%{}, batches}, fn chunk, {l1_txs, updated_batches} ->
      chunk
      # each eth_getTransactionByHash will take time since it returns entire batch
      # in `input` which is heavy because contains dozens of rollup blocks
      |> Rpc.make_chunked_request(json_rpc_named_arguments, "eth_getTransactionByHash")
      |> Enum.reduce({l1_txs, updated_batches}, fn resp, {txs_map, batches_map} ->
        block_num = quantity_to_integer(resp["blockNumber"])
        tx_hash = Rpc.strhash_to_byteshash(resp["hash"])

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
  end

  defp batches_to_rollup_txs_amounts(rollup_txs) do
    rollup_txs
    |> Enum.reduce(%{}, fn tx, acc ->
      Map.put(acc, tx.batch_number, Map.get(acc, tx.batch_number, 0) + 1)
    end)
  end

  defp get_committed_l2_to_l1_messages(highest_committed_block_number) do
    Db.initiated_l2_to_l1_messages(highest_committed_block_number)
    |> Enum.map(fn tx ->
      # credo:disable-for-previous-line Credo.Check.Refactor.PipeChainStart
      Map.put(tx, :status, :sent)
    end)
  end

  defp handle_batches_from_logs(
         logs,
         msg_to_block_shift,
         %{
           json_rpc_named_arguments: json_rpc_named_arguments,
           chunk_size: chunk_size
         } = l1_rpc_config,
         rollup_rpc_config
       ) do
    existing_batches =
      logs
      |> parse_logs_to_get_batch_numbers()
      |> Db.batches_exist()

    {batches, txs_requests, blocks_requests} = parse_logs_for_new_batches(logs, existing_batches)

    blocks_to_ts = Rpc.execute_blocks_requests_and_get_ts(blocks_requests, json_rpc_named_arguments, chunk_size)

    {lifecycle_txs_wo_indices, batches_to_import} =
      execute_tx_requests_parse_txs_calldata(txs_requests, msg_to_block_shift, blocks_to_ts, batches, l1_rpc_config)

    {blocks_to_import, rollup_txs_to_import} = get_rollup_blocks_and_transactions(batches_to_import, rollup_rpc_config)

    lifecycle_txs =
      lifecycle_txs_wo_indices
      |> Db.get_indices_for_l1_transactions()

    tx_counts_per_batch = batches_to_rollup_txs_amounts(rollup_txs_to_import)

    batches_list_to_import =
      batches_to_import
      |> Map.values()
      |> Enum.reduce([], fn batch, updated_batches_list ->
        [
          batch
          |> Map.put(:commit_id, get_l1_tx_id_by_hash(lifecycle_txs, batch.tx_hash))
          |> Map.put(
            :tx_count,
            case tx_counts_per_batch[batch.number] do
              nil -> 0
              value -> value
            end
          )
          |> Map.drop([:tx_hash])
          | updated_batches_list
        ]
      end)

    committed_txs =
      blocks_to_import
      |> Map.keys()
      |> Enum.max()
      |> get_committed_l2_to_l1_messages()

    {batches_list_to_import, Map.values(lifecycle_txs), Map.values(blocks_to_import), rollup_txs_to_import,
     committed_txs}
  end

  @doc """
  TBD
  """
  def discover(
        sequencer_inbox_address,
        start_block,
        end_block,
        new_batches_limit,
        messages_to_blocks_shift,
        l1_rpc_config,
        rollup_rpc_config
      ) do
    do_discover(
      sequencer_inbox_address,
      start_block,
      end_block,
      new_batches_limit,
      messages_to_blocks_shift,
      l1_rpc_config,
      rollup_rpc_config
    )
  end

  @doc """
  TBD
  """
  def discover_historical(
        sequencer_inbox_address,
        start_block,
        end_block,
        new_batches_limit,
        messages_to_blocks_shift,
        l1_rpc_config,
        rollup_rpc_config
      ) do
    do_discover(
      sequencer_inbox_address,
      end_block,
      start_block,
      new_batches_limit,
      messages_to_blocks_shift,
      l1_rpc_config,
      rollup_rpc_config
    )
  end

  @doc """
  TBD
  """
  defp do_discover(
         sequencer_inbox_address,
         start_block,
         end_block,
         new_batches_limit,
         messages_to_blocks_shift,
         l1_rpc_config,
         rollup_rpc_config
       ) do
    raw_logs =
      get_logs_new_batches(
        min(start_block, end_block),
        max(start_block, end_block),
        sequencer_inbox_address,
        l1_rpc_config.json_rpc_named_arguments
      )

    logs =
      if end_block >= start_block do
        raw_logs
      else
        Enum.reverse(raw_logs)
      end

    logs
    |> Enum.chunk_every(new_batches_limit)
    |> Enum.each(fn chunked_logs ->
      {batches, lifecycle_txs, rollup_blocks, rollup_txs, committed_txs} =
        handle_batches_from_logs(
          chunked_logs,
          messages_to_blocks_shift,
          l1_rpc_config,
          rollup_rpc_config
        )

      {:ok, _} =
        Chain.import(%{
          arbitrum_lifecycle_transactions: %{params: lifecycle_txs},
          arbitrum_l1_batches: %{params: batches},
          arbitrum_batch_blocks: %{params: rollup_blocks},
          arbitrum_batch_transactions: %{params: rollup_txs},
          arbitrum_messages: %{params: committed_txs},
          timeout: :infinity
        })
    end)
  end
end
