defmodule Indexer.Fetcher.ZkSync.Discovery.BatchesData do
  @moduledoc """
    Provides main functionality to extract data for batches and associated with them
    rollup blocks, rollup and L1 transactions.
  """

  alias EthereumJSONRPC.Block.ByNumber
  alias Indexer.Fetcher.ZkSync.Utils.Rpc

  import Indexer.Fetcher.ZkSync.Utils.Logging, only: [log_info: 1, log_details_chunk_handling: 4]
  import EthereumJSONRPC, only: [quantity_to_integer: 1]

  @doc """
    Downloads batches, associates rollup blocks and transactions, and imports the results into the database.
    Data is retrieved from the RPC endpoint in chunks of `chunk_size`.

    ## Parameters
    - `batches`: Either a tuple of two integers, `start_batch_number` and `end_batch_number`, defining
                 the range of batches to receive, or a list of batch numbers, `batches_list`.
    - `config`: Configuration containing `chunk_size` to limit the amount of data requested from the RPC endpoint,
                and `json_rpc_named_arguments` defining parameters for the RPC connection.

    ## Returns
    - `{batches_to_import, l2_blocks_to_import, l2_transactions_to_import}`
      where
      - `batches_to_import` is a map of batches data
      - `l2_blocks_to_import` is a list of blocks associated with batches by batch numbers
      - `l2_transactions_to_import` is a list of transactions associated with batches by batch numbers
  """
  @spec extract_data_from_batches([integer()] | {integer(), integer()}, %{
          :chunk_size => pos_integer(),
          :json_rpc_named_arguments => any(),
          optional(any()) => any()
        }) :: {map(), list(), list()}
  def extract_data_from_batches(batches, config)

  def extract_data_from_batches({start_batch_number, end_batch_number}, config)
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
    initial_batches_to_import = collect_batches_details(batches_list, config)
    log_info("Collected details for #{length(Map.keys(initial_batches_to_import))} batches")

    batches_to_import = get_block_ranges(initial_batches_to_import, config)

    {l2_blocks_to_import, l2_transactions_to_import} = get_l2_blocks_and_transactions(batches_to_import, config)
    log_info("Linked #{length(l2_blocks_to_import)} L2 blocks and #{length(l2_transactions_to_import)} L2 transactions")

    {batches_to_import, l2_blocks_to_import, l2_transactions_to_import}
  end

  @doc """
    Collects all unique L1 transactions from the given list of batches, including transactions
    that change the status of a batch and their timestamps.

    **Note**: Every map describing an L1 transaction in the response is not ready for importing into
    the database since it does not contain `:id` elements.

    ## Parameters
    - `batches`: A list of maps describing batches. Each map is expected to define the following
                 elements: `commit_transaction_hash`, `commit_timestamp`, `prove_transaction_hash`, `prove_timestamp`,
                 `executed_transaction_hash`, `executed_timestamp`.

    ## Returns
    - `l1_transactions`: A map where keys are L1 transaction hashes, and values are maps containing
      transaction hashes and timestamps.
  """
  @spec collect_l1_transactions(list()) :: map()
  def collect_l1_transactions(batches)
      when is_list(batches) do
    l1_transactions =
      batches
      |> Enum.reduce(%{}, fn batch, l1_transactions ->
        [
          %{hash: batch.commit_transaction_hash, timestamp: batch.commit_timestamp},
          %{hash: batch.prove_transaction_hash, timestamp: batch.prove_timestamp},
          %{hash: batch.executed_transaction_hash, timestamp: batch.executed_timestamp}
        ]
        |> Enum.reduce(l1_transactions, fn l1_transaction, acc ->
          # checks if l1_transaction is not empty and adds to acc
          add_l1_transaction_to_list(acc, l1_transaction)
        end)
      end)

    log_info("Collected #{length(Map.keys(l1_transactions))} L1 hashes")

    l1_transactions
  end

  defp add_l1_transaction_to_list(l1_transactions, l1_transaction) do
    if l1_transaction.hash != Rpc.get_binary_zero_hash() do
      Map.put(l1_transactions, l1_transaction.hash, l1_transaction)
    else
      l1_transactions
    end
  end

  # Divides the list of batch numbers into chunks of size `chunk_size` to combine
  # `zks_getL1BatchDetails` calls in one chunk together. To simplify further handling,
  # each call is combined with the batch number in the JSON request identifier field.
  # This allows parsing and associating every response with a particular batch, producing
  # a list of maps describing the batches, ready for further handling.
  #
  # **Note**: The batches in the resulting map are not ready for importing into the DB. L1 transaction
  #           indices as well as the rollup blocks range must be added, and then batch descriptions
  #           must be pruned (see Indexer.Fetcher.ZkSync.Utils.Db.prune_json_batch/1).
  #
  # ## Parameters
  # - `batches_list`: A list of batch numbers.
  # - `config`: A map containing `chunk_size` specifying the number of `zks_getL1BatchDetails` in
  #             one HTTP request, and `json_rpc_named_arguments` describing parameters for
  #             RPC connection.
  #
  # ## Returns
  # - `batches_details`: A map where keys are batch numbers, and values are maps produced
  #   after parsing responses of `zks_getL1BatchDetails` calls.
  defp collect_batches_details(
         batches_list,
         %{json_rpc_named_arguments: json_rpc_named_arguments, chunk_size: chunk_size} = _config
       )
       when is_list(batches_list) do
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
          requests
          |> Rpc.fetch_batches_details(json_rpc_named_arguments)
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

  # Extends each batch description with the block numbers specifying the start and end of
  # a range of blocks included in the batch. The block ranges are obtained through the RPC call
  # `zks_getL1BatchBlockRange`. The calls are combined in chunks of `chunk_size`. To distinguish
  # each call in the chunk, they are combined with the batch number in the JSON request
  # identifier field.
  #
  # ## Parameters
  # - `batches`: A map of batch descriptions.
  # - `config`: A map containing `chunk_size`, specifying the number of `zks_getL1BatchBlockRange`
  #             in one HTTP request, and `json_rpc_named_arguments` describing parameters for
  #             RPC connection.
  #
  # ## Returns
  # - `updated_batches`: A map of batch descriptions where each description is updated with
  #    a range (elements `:start_block` and `:end_block`) of rollup blocks included in the batch.
  defp get_block_ranges(
         batches,
         %{json_rpc_named_arguments: json_rpc_named_arguments, chunk_size: chunk_size} = _config
       )
       when is_map(batches) do
    keys = Map.keys(batches)
    batches_list_length = length(keys)

    {updated_batches, _} =
      keys
      |> Enum.chunk_every(chunk_size)
      |> Enum.reduce({batches, 0}, fn batches_chunk, {batches_with_block_ranges, a} ->
        log_details_chunk_handling("Collecting block ranges", batches_chunk, a * chunk_size, batches_list_length)

        {request_block_ranges_for_batches(batches_chunk, batches, batches_with_block_ranges, json_rpc_named_arguments),
         a + 1}
      end)

    updated_batches
  end

  # For a given list of rollup batch numbers, this function builds a list of requests
  # to `zks_getL1BatchBlockRange`, executes them, and extends the batches' descriptions with
  # ranges of rollup blocks associated with each batch.
  #
  # ## Parameters
  # - `batches_numbers`: A list with batch numbers.
  # - `batches_src`: A list containing original batches descriptions.
  # - `batches_dst`: A map with extended batch descriptions containing rollup block ranges.
  # - `json_rpc_named_arguments`: Describes parameters for RPC connection.
  #
  # ## Returns
  # - An updated version of `batches_dst` with new entities containing rollup block ranges.
  defp request_block_ranges_for_batches(batches_numbers, batches_src, batches_dst, json_rpc_named_arguments) do
    batches_numbers
    |> Enum.reduce([], fn batch_number, requests ->
      batch = Map.get(batches_src, batch_number)
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
    |> Enum.reduce(batches_dst, fn resp, updated_batches ->
      Map.update!(updated_batches, resp.id, fn batch ->
        [start_block, end_block] = resp.result

        Map.merge(batch, %{
          start_block: quantity_to_integer(start_block),
          end_block: quantity_to_integer(end_block)
        })
      end)
    end)
  end

  # Unfolds the ranges of rollup blocks in each batch description, makes RPC `eth_getBlockByNumber` calls,
  # and builds two lists: a list of rollup blocks associated with each batch and a list of rollup transactions
  # associated with each batch. RPC calls are made in chunks of `chunk_size`. To distinguish
  # each call in the chunk, they are combined with the block number in the JSON request
  # identifier field.
  #
  # ## Parameters
  # - `batches`: A map of batch descriptions. Each description must contain `start_block` and
  #              `end_block`, specifying the range of blocks associated with the batch.
  # - `config`: A map containing `chunk_size`, specifying the number of `eth_getBlockByNumber`
  #             in one HTTP request, and `json_rpc_named_arguments` describing parameters for
  #             RPC connection.
  #
  # ## Returns
  # - {l2_blocks_to_import, l2_transactions_to_import}, where
  #   - `l2_blocks_to_import` contains a list of all rollup blocks with their associations with
  #      the provided batches. The association is a map with the block hash and the batch number.
  #   - `l2_transactions_to_import` contains a list of all rollup transactions with their associations
  #     with the provided batches. The association is a map with the transaction hash and
  #     the batch number.
  defp get_l2_blocks_and_transactions(
         batches,
         %{json_rpc_named_arguments: json_rpc_named_arguments, chunk_size: chunk_size} = _config
       ) do
    # Extracts the rollup block range for every batch, unfolds it and
    # build chunks of `eth_getBlockByNumber` calls
    {blocks_to_batches, chunked_requests, cur_chunk, cur_chunk_size} =
      batches
      |> Map.keys()
      |> Enum.reduce({%{}, [], [], 0}, fn batch_number, cur_batch_acc ->
        batch = Map.get(batches, batch_number)

        batch.start_block..batch.end_block
        |> Enum.chunk_every(chunk_size)
        |> Enum.reduce(cur_batch_acc, fn blocks_range, cur_chunk_acc ->
          build_blocks_map_and_chunks_of_rpc_requests(batch_number, blocks_range, cur_chunk_acc, chunk_size)
        end)
      end)

    # After the last iteration of the reduce loop it is a valid case
    # when the calls from the last chunk are not in the chunks list,
    # so it is appended
    finalized_chunked_requests =
      if cur_chunk_size > 0 do
        [cur_chunk | chunked_requests]
      else
        chunked_requests
      end

    # The chunks requests are sent to the RPC node and parsed to
    # extract rollup block hashes and rollup transactions.
    {blocks_associations, l2_transactions_to_import} =
      finalized_chunked_requests
      |> Enum.reduce({blocks_to_batches, []}, fn requests, {blocks, l2_transactions} ->
        requests
        |> Rpc.fetch_blocks_details(json_rpc_named_arguments)
        |> extract_block_hash_and_transactions_list(blocks, l2_transactions)
      end)

    # Check that amount of received transactions for a batch is correct
    batches
    |> Map.keys()
    |> Enum.each(fn batch_number ->
      batch = Map.get(batches, batch_number)
      transactions_in_batch = batch.l1_transaction_count + batch.l2_transaction_count

      ^transactions_in_batch =
        Enum.count(l2_transactions_to_import, fn transaction ->
          transaction.batch_number == batch_number
        end)
    end)

    {Map.values(blocks_associations), l2_transactions_to_import}
  end

  # For a given list of rollup block numbers, this function extends:
  # - a map containing the linkage between rollup block numbers and batch numbers
  # - a list of chunks of `eth_getBlockByNumber` requests
  # - an uncompleted chunk of `eth_getBlockByNumber` requests
  #
  # ## Parameters
  # - `batch_number`: The number of the batch to which the list of rollup blocks is linked.
  # - `blocks_numbers`: A list of rollup block numbers.
  # - `cur_chunk_acc`: The current state of the accumulator containing:
  #   - the current state of the map containing the linkage between rollup block numbers and batch numbers
  #   - the current state of the list of chunks of `eth_getBlockByNumber` requests
  #   - the current state of the uncompleted chunk of `eth_getBlockByNumber` requests
  #   - the size of the uncompleted chunk
  # - `chunk_size`: The maximum size of the chunk of `eth_getBlockByNumber` requests
  #
  # ## Returns
  # - {blocks_to_batches, chunked_requests, cur_chunk, cur_chunk_size}, where:
  #   - `blocks_to_batches`: An updated map with new blocks added.
  #   - `chunked_requests`: An updated list of lists of `eth_getBlockByNumber` requests.
  #   - `cur_chunk`: An uncompleted chunk of `eth_getBlockByNumber` requests or an empty list.
  #   - `cur_chunk_size`: The size of the uncompleted chunk.
  defp build_blocks_map_and_chunks_of_rpc_requests(batch_number, blocks_numbers, cur_chunk_acc, chunk_size) do
    blocks_numbers
    |> Enum.reduce(cur_chunk_acc, fn block_number, {blocks_to_batches, chunked_requests, cur_chunk, cur_chunk_size} ->
      blocks_to_batches = Map.put(blocks_to_batches, block_number, %{batch_number: batch_number})

      cur_chunk = [
        ByNumber.request(
          %{
            id: block_number,
            number: block_number
          },
          false
        )
        | cur_chunk
      ]

      if cur_chunk_size + 1 == chunk_size do
        {blocks_to_batches, [cur_chunk | chunked_requests], [], 0}
      else
        {blocks_to_batches, chunked_requests, cur_chunk, cur_chunk_size + 1}
      end
    end)
  end

  # Parses responses from `eth_getBlockByNumber` calls and extracts the block hash and the
  # transactions lists. The block hash and transaction hashes are used to build associations
  # with the corresponding batches by utilizing their numbers.
  #
  # This function is not part of the `Indexer.Fetcher.ZkSync.Utils.Rpc` module since the resulting
  # lists are too specific for further import to the database.
  #
  # ## Parameters
  # - `json_responses`: A list of responses to `eth_getBlockByNumber` calls.
  # - `l2_blocks`: A map of accumulated associations between rollup blocks and batches.
  # - `l2_transactions`: A list of accumulated associations between rollup transactions and batches.
  #
  # ## Returns
  # - {l2_blocks, l2_transactions}, where
  #   - `l2_blocks`: Updated map of accumulated associations between rollup blocks and batches.
  #   - `l2_transactions`: Updated list of accumulated associations between rollup transactions and batches.
  defp extract_block_hash_and_transactions_list(json_responses, l2_blocks, l2_transactions) do
    json_responses
    |> Enum.reduce({l2_blocks, l2_transactions}, fn resp, {l2_blocks, l2_transactions} ->
      {block, l2_blocks} =
        Map.get_and_update(l2_blocks, resp.id, fn block ->
          {block, Map.put(block, :hash, Map.get(resp.result, "hash"))}
        end)

      l2_transactions =
        case Map.get(resp.result, "transactions") do
          nil ->
            l2_transactions

          new_transactions ->
            Enum.reduce(new_transactions, l2_transactions, fn l2_transaction_hash, l2_transactions ->
              [
                %{
                  batch_number: block.batch_number,
                  transaction_hash: l2_transaction_hash
                }
                | l2_transactions
              ]
            end)
        end

      {l2_blocks, l2_transactions}
    end)
  end
end
