defmodule Indexer.Fetcher.ZkSync.Discovery.BatchesData do
  alias Indexer.Fetcher.ZkSync.Utils.Rpc

  import Indexer.Fetcher.ZkSync.Utils.Logging, only: [log_info: 1, log_details_chunk_handling: 4]
  import EthereumJSONRPC, only: [integer_to_quantity: 1, quantity_to_integer: 1]

  def extract_data_from_batches(start_batch_number, end_batch_number, config)
      when is_integer(start_batch_number) and is_integer(end_batch_number) and
             is_map(config) do
    start_batch_number..end_batch_number
    |> Enum.to_list()
    |> do_extract_data_from_batches(config)
  end

  def extract_data_from_batches(batches_list, config)
      when is_list(batches_list) and
             is_map(config) do
    batches_list
    |> do_extract_data_from_batches(config)
  end

  defp do_extract_data_from_batches(batches_list, config) when is_list(batches_list) do
    batches_to_import = collect_batches_details(batches_list, config)
    log_info("Collected details for #{length(Map.keys(batches_to_import))} batches")

    batches_to_import = get_block_ranges(batches_to_import, config)

    {l2_blocks_to_import, l2_txs_to_import} = get_l2_blocks_and_transactions(batches_to_import, config)
    log_info("Linked #{length(l2_blocks_to_import)} L2 blocks and #{length(l2_txs_to_import)} L2 transactions")

    {batches_to_import, l2_blocks_to_import, l2_txs_to_import}
  end

  def collect_l1_transactions(batches) do
    l1_txs =
      Map.values(batches)
      |> Enum.reduce(%{}, fn batch, l1_txs ->
        [
          %{hash: batch.commit_tx_hash, timestamp: batch.commit_timestamp},
          %{hash: batch.prove_tx_hash, timestamp: batch.prove_timestamp},
          %{hash: batch.executed_tx_hash, timestamp: batch.executed_timestamp}
        ]
        |> Enum.reduce(l1_txs, fn l1_tx, acc ->
          if l1_tx.hash != Rpc.get_binary_zero_hash() do
            Map.put(acc, l1_tx.hash, l1_tx)
          else
            acc
          end
        end)
      end)

    log_info("Collected #{length(Map.keys(l1_txs))} L1 hashes")

    l1_txs
  end

  defp collect_batches_details(
         batches_list,
         %{json_rpc_named_arguments: json_rpc_named_arguments, chunk_size: chunk_size} = _config
       ) do
    batches_list_length = length(batches_list)

    {batches_details, _} =
      batches_list
      |> Enum.chunk_every(chunk_size)
      |> Enum.reduce({%{}, 0}, fn chunk, {details, a} ->
        log_details_chunk_handling("Collecting details", chunk, a * chunk_size, batches_list_length)

        requests =
          chunk
          |> Enum.map(fn batch_number ->
            EthereumJSONRPC.request(%{
              id: batch_number,
              method: "zks_getL1BatchDetails",
              params: [batch_number]
            })
          end)

        details =
          Rpc.fetch_batches_details(requests, json_rpc_named_arguments)
          |> Enum.reduce(
            details,
            fn resp, details ->
              Map.put(details, resp.id, Rpc.transform_batch_details_to_map(resp.result))
            end
          )

        {details, a + 1}
      end)

    batches_details
  end

  defp get_block_ranges(
         batches,
         %{json_rpc_named_arguments: json_rpc_named_arguments, chunk_size: chunk_size} = _config
       ) do
    keys = Map.keys(batches)
    batches_list_length = length(keys)
    # The main goal of this reduce to get blocks ranges for every batch
    # by combining zks_getL1BatchBlockRange requests in chunks
    {updated_batches, _} =
      keys
      |> Enum.chunk_every(chunk_size)
      |> Enum.reduce({batches, 0}, fn batches_chunk, {batches_with_blockranges, a} = _acc ->
        log_details_chunk_handling("Collecting block ranges", batches_chunk, a * chunk_size, batches_list_length)

        # Execute requests list and extend the batches details with blocks ranges
        batches_with_blockranges =
          batches_chunk
          |> Enum.reduce([], fn batch_number, requests ->
            batch = Map.get(batches, batch_number)
            # Prepare requests list to get blocks ranges
            case is_nil(batch.start_block) or is_nil(batch.end_block) do
              true ->
                [
                  EthereumJSONRPC.request(%{
                    id: batch_number,
                    method: "zks_getL1BatchBlockRange",
                    params: [batch_number]
                  })
                  | requests
                ]

              false ->
                requests
            end
          end)
          |> Rpc.fetch_blocks_ranges(json_rpc_named_arguments)
          |> Enum.reduce(batches_with_blockranges, fn resp, batches_with_blockranges ->
            Map.update!(batches_with_blockranges, resp.id, fn batch ->
              [start_block, end_block] = resp.result

              Map.merge(batch, %{
                start_block: quantity_to_integer(start_block),
                end_block: quantity_to_integer(end_block)
              })
            end)
          end)

        {batches_with_blockranges, a + 1}
      end)

    updated_batches
  end

  defp get_l2_blocks_and_transactions(
         batches,
         %{json_rpc_named_arguments: json_rpc_named_arguments, chunk_size: chunk_size} = _config
       ) do
    {blocks, chunked_requests, cur_chunk, cur_chunk_size} =
      Map.keys(batches)
      |> Enum.reduce({%{}, [], [], 0}, fn batch_number, {blocks, chunked_requests, cur_chunk, cur_chunk_size} = _acc ->
        batch = Map.get(batches, batch_number)
        # log_info("The batch #{batch_number} contains blocks range #{batch.start_block}..#{batch.end_block}")
        batch.start_block..batch.end_block
        |> Enum.chunk_every(chunk_size)
        |> Enum.reduce({blocks, chunked_requests, cur_chunk, cur_chunk_size}, fn blocks_range,
                                                                                 {blks, chnkd_rqsts, c_chunk,
                                                                                  c_chunk_size} = _acc ->
          blocks_range
          |> Enum.reduce({blks, chnkd_rqsts, c_chunk, c_chunk_size}, fn block_number,
                                                                        {blks, chnkd_rqsts, c_chunk, c_chunk_size} =
                                                                          _acc ->
            blks = Map.put(blks, block_number, %{batch_number: batch_number})

            c_chunk = [
              EthereumJSONRPC.request(%{
                id: block_number,
                method: "eth_getBlockByNumber",
                params: [integer_to_quantity(block_number), false]
              })
              | c_chunk
            ]

            if c_chunk_size + 1 == chunk_size do
              {blks, [c_chunk | chnkd_rqsts], [], 0}
            else
              {blks, chnkd_rqsts, c_chunk, c_chunk_size + 1}
            end
          end)
        end)
      end)

    chunked_requests =
      if cur_chunk_size > 0 do
        [cur_chunk | chunked_requests]
      else
        chunked_requests
      end

    {blocks, l2_txs_to_import} =
      chunked_requests
      |> Enum.reduce({blocks, []}, fn requests, {blocks, l2_txs} ->
        Rpc.fetch_blocks_details(requests, json_rpc_named_arguments)
        |> extract_block_hash_and_transactions_list(blocks, l2_txs)
      end)

    # Check that amount of received transactions for a batch is correct
    Map.keys(batches)
    |> Enum.each(fn batch_number ->
      batch = Map.get(batches, batch_number)
      txs_in_batch = batch.l1_tx_count + batch.l2_tx_count

      ^txs_in_batch =
        Enum.count(l2_txs_to_import, fn tx ->
          tx.batch_number == batch_number
        end)
    end)

    {Map.values(blocks), l2_txs_to_import}
  end

  defp extract_block_hash_and_transactions_list(json_responses, l2_blocks, l2_txs) do
    json_responses
    |> Enum.reduce({l2_blocks, l2_txs}, fn resp, {l2_blocks, l2_txs} ->
      {block, l2_blocks} =
        Map.get_and_update(l2_blocks, resp.id, fn block ->
          {block, Map.put(block, :hash, Map.get(resp.result, "hash"))}
        end)

      l2_txs =
        Map.get(resp.result, "transactions")
        |> Kernel.||([])
        |> Enum.reduce(l2_txs, fn l2_tx_hash, l2_txs ->
          [
            %{
              batch_number: block.batch_number,
              hash: l2_tx_hash
            }
            | l2_txs
          ]
        end)

      {l2_blocks, l2_txs}
    end)
  end
end
