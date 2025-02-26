defmodule Indexer.Fetcher.Arbitrum.Workers.Batches.RollupEntities do
  @moduledoc """
  The module associates rollup blocks and transactions with their corresponding batches in the Arbitrum blockchain.
  """

  import EthereumJSONRPC, only: [quantity_to_integer: 1]

  import Indexer.Fetcher.Arbitrum.Utils.Logging, only: [log_info: 1, log_debug: 1]

  alias EthereumJSONRPC.Block.ByNumber, as: BlockByNumber

  alias Explorer.Chain.Arbitrum

  alias Indexer.Fetcher.Arbitrum.Utils.Db.Common, as: DbCommon
  alias Indexer.Fetcher.Arbitrum.Utils.{Logging, Rpc}

  require Logger

  @doc """
    Retrieves and associates rollup blocks and transactions for a list of batches.

    Extracts rollup block ranges from batch data and fetches the corresponding blocks
    and transactions from the database. If any required data is missing, it attempts
    to recover it through RPC calls.

    ## Parameters
    - `batches`: Map where keys are batch numbers and values are maps containing:
      - `:number`: Batch number
      - `:start_block`: Starting rollup block number
      - `:end_block`: Ending rollup block number
    - `rollup_rpc_config`: Configuration map containing:
      - `:json_rpc_named_arguments`: Arguments for JSON RPC calls
      - `:chunk_size`: Size of chunks for batch processing

    ## Returns
    - Tuple containing:
      - Map of rollup blocks ready for database import, keyed by block number
      - List of rollup transactions ready for database import
  """
  @spec associate_rollup_blocks_and_transactions(
          %{
            non_neg_integer() => %{
              :number => non_neg_integer(),
              :start_block => non_neg_integer(),
              :end_block => non_neg_integer(),
              optional(any()) => any()
            }
          },
          %{
            :json_rpc_named_arguments => EthereumJSONRPC.json_rpc_named_arguments(),
            :chunk_size => non_neg_integer(),
            optional(any()) => any()
          }
        ) ::
          {%{non_neg_integer() => Arbitrum.BatchBlock.to_import()}, [Arbitrum.BatchTransaction.to_import()]}
  def associate_rollup_blocks_and_transactions(
        batches,
        rollup_rpc_config
      ) do
    blocks_to_batches = unwrap_rollup_block_ranges(batches)

    required_blocks_numbers = Map.keys(blocks_to_batches)

    if required_blocks_numbers == [] do
      {%{}, []}
    else
      log_debug("Identified #{length(required_blocks_numbers)} rollup blocks")

      {blocks_to_import_map, transactions_to_import_list} =
        get_rollup_blocks_and_transactions_from_db(required_blocks_numbers, blocks_to_batches)

      # While it's not entirely aligned with data integrity principles to recover
      # rollup blocks and transactions from RPC that are not yet indexed, it's
      # a practical compromise to facilitate the progress of batch discovery. Given
      # the potential high frequency of new batch appearances and the substantial
      # volume of blocks and transactions, prioritizing discovery process advancement
      # is deemed reasonable.
      {blocks_to_import, transactions_to_import} =
        recover_data_if_necessary(
          blocks_to_import_map,
          transactions_to_import_list,
          required_blocks_numbers,
          blocks_to_batches,
          rollup_rpc_config
        )

      log_info(
        "Found #{length(Map.keys(blocks_to_import))} rollup blocks and #{length(transactions_to_import)} rollup transactions in DB"
      )

      {blocks_to_import, transactions_to_import}
    end
  end

  # Unwraps rollup block ranges from batch data to create a block-to-batch number map.
  #
  # ## Parameters
  # - `batches`: A map where keys are batch identifiers and values are structs
  #              containing the start and end blocks of each batch.
  #
  # ## Returns
  # - A map where each key is a rollup block number and its value is the
  #   corresponding batch number.
  @spec unwrap_rollup_block_ranges(%{
          non_neg_integer() => %{
            :start_block => non_neg_integer(),
            :end_block => non_neg_integer(),
            :number => non_neg_integer(),
            optional(any()) => any()
          }
        }) :: %{non_neg_integer() => non_neg_integer()}
  defp unwrap_rollup_block_ranges(batches) do
    batches
    |> Map.values()
    |> Enum.reduce(%{}, fn batch, b_2_b ->
      batch.start_block..batch.end_block
      |> Enum.reduce(b_2_b, fn block_number, b_2_b_inner ->
        Map.put(b_2_b_inner, block_number, batch.number)
      end)
    end)
  end

  # Retrieves rollup blocks and transactions from the database based on given block numbers.
  #
  # This function fetches rollup blocks from the database using provided block numbers.
  # For each block, it constructs a map of rollup block details and a list of
  # transactions, including the batch number from `blocks_to_batches` mapping, block
  # hash, and transaction hash.
  #
  # ## Parameters
  # - `rollup_blocks_numbers`: A list of rollup block numbers to retrieve from the
  #                            database.
  # - `blocks_to_batches`: A mapping from block numbers to batch numbers.
  #
  # ## Returns
  # - A tuple containing:
  #   - A map of rollup blocks associated with the batch numbers, ready for
  #     database import.
  #   - A list of transactions, each associated with its respective rollup block
  #     and batch number, ready for database import.
  @spec get_rollup_blocks_and_transactions_from_db(
          [non_neg_integer()],
          %{non_neg_integer() => non_neg_integer()}
        ) :: {%{non_neg_integer() => Arbitrum.BatchBlock.to_import()}, [Arbitrum.BatchTransaction.to_import()]}
  defp get_rollup_blocks_and_transactions_from_db(rollup_blocks_numbers, blocks_to_batches) do
    rollup_blocks_numbers
    |> DbCommon.rollup_blocks()
    |> Enum.reduce({%{}, []}, fn block, {blocks_map, transactions_list} ->
      batch_num = blocks_to_batches[block.number]

      updated_transactions_list =
        block.transactions
        |> Enum.reduce(transactions_list, fn transaction, acc ->
          [%{transaction_hash: transaction.hash.bytes, batch_number: batch_num} | acc]
        end)

      updated_blocks_map =
        blocks_map
        |> Map.put(block.number, %{
          block_number: block.number,
          batch_number: batch_num,
          confirmation_id: nil
        })

      {updated_blocks_map, updated_transactions_list}
    end)
  end

  # Recovers missing rollup blocks and transactions from the RPC if not all required blocks are found in the current data.
  #
  # This function compares the required rollup block numbers with the ones already
  # present in the current data. If some blocks are missing, it retrieves them from
  # the RPC along with their transactions. The retrieved blocks and transactions
  # are then merged with the current data to ensure a complete set for further
  # processing.
  #
  # ## Parameters
  # - `current_rollup_blocks`: The map of rollup blocks currently held.
  # - `current_rollup_transactions`: The list of transactions currently held.
  # - `required_blocks_numbers`: A list of block numbers that are required for
  #                              processing.
  # - `blocks_to_batches`: A map associating rollup block numbers with batch numbers.
  # - `rollup_rpc_config`: Configuration for the RPC calls.
  #
  # ## Returns
  # - A tuple containing the updated map of rollup blocks and the updated list of
  #   transactions, both are ready for database import.
  @spec recover_data_if_necessary(
          %{non_neg_integer() => Arbitrum.BatchBlock.to_import()},
          [Arbitrum.BatchTransaction.to_import()],
          [non_neg_integer()],
          %{non_neg_integer() => non_neg_integer()},
          %{
            :json_rpc_named_arguments => EthereumJSONRPC.json_rpc_named_arguments(),
            :chunk_size => non_neg_integer(),
            optional(any()) => any()
          }
        ) ::
          {%{non_neg_integer() => Arbitrum.BatchBlock.to_import()}, [Arbitrum.BatchTransaction.to_import()]}
  defp recover_data_if_necessary(
         current_rollup_blocks,
         current_rollup_transactions,
         required_blocks_numbers,
         blocks_to_batches,
         rollup_rpc_config
       ) do
    required_blocks_amount = length(required_blocks_numbers)

    found_blocks_numbers = Map.keys(current_rollup_blocks)
    found_blocks_numbers_length = length(found_blocks_numbers)

    if found_blocks_numbers_length != required_blocks_amount do
      log_info("Only #{found_blocks_numbers_length} of #{required_blocks_amount} rollup blocks found in DB")

      {recovered_blocks_map, recovered_transactions_list, _} =
        recover_rollup_blocks_and_transactions_from_rpc(
          required_blocks_numbers,
          found_blocks_numbers,
          blocks_to_batches,
          rollup_rpc_config
        )

      {Map.merge(current_rollup_blocks, recovered_blocks_map),
       current_rollup_transactions ++ recovered_transactions_list}
    else
      {current_rollup_blocks, current_rollup_transactions}
    end
  end

  # Recovers missing rollup blocks and their transactions from RPC based on required block numbers.
  #
  # This function identifies missing rollup blocks by comparing the required block
  # numbers with those already found. It then fetches the missing blocks in chunks
  # using JSON RPC calls, aggregating the results into a map of rollup blocks and
  # a list of transactions. The data is processed to ensure each block and its
  # transactions are correctly associated with their batch number.
  #
  # ## Parameters
  # - `required_blocks_numbers`: A list of block numbers that are required to be
  #                              fetched.
  # - `found_blocks_numbers`: A list of block numbers that have already been
  #                           fetched.
  # - `blocks_to_batches`: A map linking block numbers to their respective batch
  #                        numbers.
  # - `rollup_rpc_config`: A map containing configuration parameters including
  #                        JSON RPC arguments for rollup RPC and the chunk size
  #                        for batch processing.
  #
  # ## Returns
  # - A tuple containing:
  #   - A map of rollup blocks associated with the batch numbers, ready for
  #     database import.
  #   - A list of transactions, each associated with its respective rollup
  #     block and batch number, ready for database import.
  #   - The updated counter of processed chunks (usually ignored).
  @spec recover_rollup_blocks_and_transactions_from_rpc(
          [non_neg_integer()],
          [non_neg_integer()],
          %{non_neg_integer() => non_neg_integer()},
          %{
            :json_rpc_named_arguments => EthereumJSONRPC.json_rpc_named_arguments(),
            :chunk_size => non_neg_integer(),
            optional(any()) => any()
          }
        ) ::
          {%{non_neg_integer() => Arbitrum.BatchBlock.to_import()}, [Arbitrum.BatchTransaction.to_import()],
           non_neg_integer()}
  defp recover_rollup_blocks_and_transactions_from_rpc(
         required_blocks_numbers,
         found_blocks_numbers,
         blocks_to_batches,
         %{
           json_rpc_named_arguments: rollup_json_rpc_named_arguments,
           chunk_size: rollup_chunk_size
         } = _rollup_rpc_config
       ) do
    missed_blocks = required_blocks_numbers -- found_blocks_numbers
    missed_blocks_length = length(missed_blocks)

    missed_blocks
    |> Enum.sort()
    |> Enum.chunk_every(rollup_chunk_size)
    |> Enum.reduce({%{}, [], 0}, fn chunk, {blocks_map, transactions_list, chunks_counter} ->
      Logging.log_details_chunk_handling(
        "Collecting rollup data",
        {"block", "blocks"},
        chunk,
        chunks_counter,
        missed_blocks_length
      )

      requests =
        chunk
        |> Enum.reduce([], fn block_number, requests_list ->
          [
            BlockByNumber.request(
              %{
                id: blocks_to_batches[block_number],
                number: block_number
              },
              false
            )
            | requests_list
          ]
        end)

      {blocks_map_updated, transactions_list_updated} =
        requests
        |> Rpc.make_chunked_request_keep_id(rollup_json_rpc_named_arguments, "eth_getBlockByNumber")
        |> prepare_rollup_block_map_and_transactions_list(blocks_map, transactions_list)

      {blocks_map_updated, transactions_list_updated, chunks_counter + length(chunk)}
    end)
  end

  # Processes JSON responses to construct a mapping of rollup block information and a list of transactions.
  #
  # This function takes JSON RPC responses for rollup blocks and processes each
  # response to create a mapping of rollup block details and a comprehensive list
  # of transactions associated with these blocks. It ensures that each block and its
  # corresponding transactions are correctly associated with their batch number.
  #
  # ## Parameters
  # - `json_responses`: A list of JSON RPC responses containing rollup block data.
  # - `rollup_blocks`: The initial map of rollup block information.
  # - `rollup_transactions`: The initial list of rollup transactions.
  #
  # ## Returns
  # - A tuple containing:
  #   - An updated map of rollup blocks associated with their batch numbers, ready
  #     for database import.
  #   - An updated list of transactions, each associated with its respective rollup
  #     block and batch number, ready for database import.
  @spec prepare_rollup_block_map_and_transactions_list(
          [%{id: non_neg_integer(), result: %{String.t() => any()}}],
          %{non_neg_integer() => Arbitrum.BatchBlock.to_import()},
          [Arbitrum.BatchTransaction.to_import()]
        ) :: {%{non_neg_integer() => Arbitrum.BatchBlock.to_import()}, [Arbitrum.BatchTransaction.to_import()]}
  defp prepare_rollup_block_map_and_transactions_list(json_responses, rollup_blocks, rollup_transactions) do
    json_responses
    |> Enum.reduce({rollup_blocks, rollup_transactions}, fn resp, {blocks_map, transactions_list} ->
      batch_num = resp.id
      blk_num = quantity_to_integer(resp.result["number"])

      updated_blocks_map =
        Map.put(
          blocks_map,
          blk_num,
          %{block_number: blk_num, batch_number: batch_num, confirmation_id: nil}
        )

      updated_transactions_list =
        case resp.result["transactions"] do
          nil ->
            transactions_list

          new_transactions ->
            Enum.reduce(new_transactions, transactions_list, fn l2_transaction_hash, transactions_list ->
              [%{transaction_hash: l2_transaction_hash, batch_number: batch_num} | transactions_list]
            end)
        end

      {updated_blocks_map, updated_transactions_list}
    end)
  end

  @doc """
    Aggregates rollup transactions to provide a count per batch number.

    ## Parameters
    - `rollup_transactions`: List of rollup transaction maps, where each map contains
      `:transaction_hash` and `:batch_number` keys

    ## Returns
    - Map where keys are batch numbers and values are the count of transactions in
      that batch
  """
  @spec batches_to_rollup_transactions_amounts([Arbitrum.BatchTransaction.to_import()]) :: %{
          non_neg_integer() => non_neg_integer()
        }
  def batches_to_rollup_transactions_amounts(rollup_transactions) do
    rollup_transactions
    |> Enum.reduce(%{}, fn transaction, acc ->
      Map.put(acc, transaction.batch_number, Map.get(acc, transaction.batch_number, 0) + 1)
    end)
  end
end
