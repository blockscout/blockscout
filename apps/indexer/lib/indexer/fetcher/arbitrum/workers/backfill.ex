defmodule Indexer.Fetcher.Arbitrum.Workers.Backfill do
  @moduledoc """
    Handles backfilling of missing Arbitrum-specific data for indexed blocks and their
    transactions.

    This module discovers blocks that are missing Arbitrum L2-specific information and
    fetches this data from the Arbitrum RPC endpoint. It processes blocks in configurable
    chunks and updates the following fields:

    For blocks: `send_count`, `send_root` and `l1_block_number`

    For transactions: `gas_used_for_l1`

    The module operates within a specified block range and ensures all blocks are properly
    indexed before attempting to backfill the missing Arbitrum-specific information. All
    database updates are performed in a single transaction to maintain data consistency.

    ## Receipt Collection Strategy

    When fetching transaction receipts, the module first attempts to collect receipts for
    multiple blocks in batches using `eth_getBlockReceipts`. If this fails, it falls back
    to fetching individual transaction receipts using `eth_getTransactionReceipt`.
  """

  import Ecto.Query
  import Indexer.Fetcher.Arbitrum.Utils.Logging, only: [log_warning: 1, log_debug: 1, log_info: 1]

  alias EthereumJSONRPC.{Blocks, Receipts}
  alias Explorer.Chain.Block, as: RollupBlock
  alias Explorer.Chain.Hash
  alias Explorer.Chain.Transaction, as: RollupTransaction
  alias Explorer.Repo

  alias Indexer.Fetcher.Arbitrum.Utils.Db.Common, as: ArbitrumDbUtils

  alias Ecto.Multi

  require Logger

  @doc """
    Discovers and backfills missing Arbitrum-specific fields for blocks and their
    transactions within a calculated range.

    Calculates a block range based on the end block and verifies that all blocks
    in this range are indexed before attempting to discover and backfill missing fields.

    ## Parameters
    - `end_block`: The upper bound block number for the discovery range
    - `state`: Configuration map containing:
      - `:config`: Configuration settings with:
        - `:rollup_rpc`: Rollup RPC settings with:
          - `:first_block`: The block number which is considered as the first block
            of the rollup
        - `:backfill_blocks_depth`: Number of blocks to look back from `end_block`

    ## Returns
    - `{:ok, start_block}` if backfill completed successfully, where `start_block` is the
      lower bound of the processed range
    - `{:error, :discover_blocks_error}` if backfill failed
    - `{:error, :not_indexed_blocks}` if some blocks in the range are not indexed
  """
  @spec discover_blocks(
          non_neg_integer(),
          %{
            :config => %{
              :rollup_rpc => %{
                :first_block => non_neg_integer(),
                optional(atom()) => any()
              },
              :backfill_blocks_depth => non_neg_integer(),
              optional(atom()) => any()
            }
          }
        ) :: {:ok, non_neg_integer()} | {:error, atom()}
  def discover_blocks(end_block, state) do
    # and then to backfill only by chunk size, larger buckets are more
    # efficient in cases where most blocks in the chain do not require
    # backfilling.
    start_block = max(state.config.rollup_rpc.first_block, end_block - state.config.backfill_blocks_depth + 1)

    if ArbitrumDbUtils.indexed_blocks?(start_block, end_block) do
      case do_discover_blocks(start_block, end_block, state) do
        :ok -> {:ok, start_block}
        :error -> {:error, :discover_blocks_error}
      end
    else
      log_warning(
        "Not able to discover rollup blocks to backfill, some blocks in #{start_block}..#{end_block} not indexed"
      )

      {:error, :not_indexed_blocks}
    end
  end

  # Discovers and backfills missing Arbitrum-specific fields for blocks within a given range.
  #
  # Identifies blocks with missing Arbitrum fields within the specified range and initiates
  # the backfill process for those blocks requesting the data by JSON RPC.
  #
  # ## Parameters
  # - `start_block`: The first block number in the range to check
  # - `end_block`: The last block number in the range to check
  # - `state`: Configuration map containing:
  #   - `:config`: RPC configuration with:
  #     - `:rollup_rpc`: Rollup RPC settings with:
  #       - `:chunk_size`: Maximum number of blocks per RPC request
  #       - `:json_rpc_named_arguments`: RPC connection configuration
  #
  # ## Returns
  # - `:ok` if backfill completed successfully
  # - `:error` if backfill failed on any stage
  @spec do_discover_blocks(
          start_block :: non_neg_integer(),
          end_block :: non_neg_integer(),
          %{
            :config => %{
              :rollup_rpc => %{
                :chunk_size => non_neg_integer(),
                :json_rpc_named_arguments => EthereumJSONRPC.json_rpc_named_arguments(),
                optional(atom()) => any()
              },
              optional(atom()) => any()
            },
            optional(atom()) => any()
          }
        ) :: :ok | :error
  defp do_discover_blocks(start_block, end_block, %{
         config: %{rollup_rpc: %{chunk_size: chunk_size, json_rpc_named_arguments: json_rpc_named_arguments}}
       }) do
    log_info("Block range for blocks information backfill: #{start_block}..#{end_block}")

    block_numbers = ArbitrumDbUtils.blocks_with_missing_fields(start_block, end_block)

    log_debug("Backfilling #{length(block_numbers)} blocks")

    backfill_for_blocks(block_numbers, json_rpc_named_arguments, chunk_size)
  end

  # Retrieves block data and transaction receipts for a list of block numbers and
  # updates the database.
  #
  # Fetches blocks and their transaction receipts in chunks, then updates the database
  # with the retrieved information. Returns early if any fetch operation fails.
  #
  # ## Parameters
  # - `block_numbers`: List of block numbers to backfill
  # - `json_rpc_named_arguments`: Configuration for JSON-RPC connection
  # - `chunk_size`: Maximum number of blocks to fetch in a single request
  #
  # ## Returns
  # - `:ok` - Successfully fetched and updated all blocks
  # - `:error` - Failed to fetch or update blocks
  @spec backfill_for_blocks(
          [non_neg_integer()],
          EthereumJSONRPC.json_rpc_named_arguments(),
          non_neg_integer()
        ) :: :ok | :error
  defp backfill_for_blocks(block_numbers, json_rpc_named_arguments, chunk_size) do
    with {:ok, blocks} <- fetch_blocks(block_numbers, json_rpc_named_arguments, chunk_size),
         {:ok, receipts} <-
           fetch_receipts_with_fallback(block_numbers, json_rpc_named_arguments, chunk_size, chunk_size) do
      update_db(blocks, receipts)
    else
      {:error, _} -> :error
    end
  end

  # Makes JSON RPC requests in chunks to retrieve block data for a list of block
  # numbers.
  #
  # ## Parameters
  # - `block_numbers`: List of block numbers to fetch
  # - `json_rpc_named_arguments`: Configuration for JSON-RPC connection
  # - `chunk_size`: Maximum number of blocks to fetch in a single request
  #
  # ## Returns
  # - `{:ok, [map()]}`: List of block parameters on successful fetch
  # - `{:error, any()}`: Error details if fetch fails
  @spec fetch_blocks(
          block_numbers :: [non_neg_integer()],
          json_rpc_named_arguments :: EthereumJSONRPC.json_rpc_named_arguments(),
          chunk_size :: non_neg_integer()
        ) :: {:ok, [map()]} | {:error, any()}
  defp fetch_blocks(block_numbers, json_rpc_named_arguments, chunk_size) do
    block_numbers
    |> Enum.chunk_every(chunk_size)
    |> Enum.reduce_while({:ok, []}, fn chunk, {:ok, acc} ->
      case EthereumJSONRPC.fetch_blocks_by_numbers(chunk, json_rpc_named_arguments, false) do
        {:ok, %Blocks{blocks_params: blocks}} -> {:cont, {:ok, acc ++ blocks}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  # Recursively fetches transaction receipts with fallback mechanisms for large blocks.
  #
  # This function implements a fallback strategy for fetching transaction receipts:
  # 1. First attempts to fetch receipts for blocks in chunks using eth_getBlockReceipts
  # 2. If a chunk fails, retries with half the chunk size
  # 3. For single blocks that fail, falls back to fetching individual transaction receipts
  #
  # ## Parameters
  # - `block_numbers`: List of block numbers to fetch receipts for
  # - `json_rpc_named_arguments`: Configuration for JSON-RPC connection
  # - `current_chunk_size`: Current maximum number of blocks to fetch in a single request
  # - `original_chunk_size`: Original chunk size from fetch_blocks (used for transaction batching)
  #
  # ## Returns
  # - `{:ok, receipts}` with list of successfully fetched receipts
  # - `{:error, reason}` if fetching fails even with fallback mechanisms
  @spec fetch_receipts_with_fallback(
          [non_neg_integer()],
          EthereumJSONRPC.json_rpc_named_arguments(),
          non_neg_integer(),
          non_neg_integer()
        ) :: {:ok, [map()]} | {:error, any()}
  defp fetch_receipts_with_fallback([], _json_rpc_named_arguments, _current_chunk_size, _original_chunk_size),
    do: {:ok, []}

  defp fetch_receipts_with_fallback([block_number], json_rpc_named_arguments, _current_chunk_size, original_chunk_size) do
    # For a single block, try eth_getBlockReceipts first
    case Receipts.fetch_by_block_numbers([block_number], json_rpc_named_arguments) do
      {:ok, %{receipts: receipts}} ->
        {:ok, receipts}

      {:error, _} ->
        # If that fails, try fetching individual transaction receipts
        fetch_individual_receipts(block_number, json_rpc_named_arguments, original_chunk_size)
    end
  end

  defp fetch_receipts_with_fallback(block_numbers, json_rpc_named_arguments, current_chunk_size, original_chunk_size) do
    block_numbers
    |> Enum.chunk_every(current_chunk_size)
    |> Enum.reduce_while({:ok, []}, fn chunk, {:ok, acc} ->
      case Receipts.fetch_by_block_numbers(chunk, json_rpc_named_arguments) do
        {:ok, %{receipts: receipts}} ->
          {:cont, {:ok, acc ++ receipts}}

        {:error, reason} ->
          log_warning(
            "Block receipts request failed for blocks #{Enum.min(chunk)}..#{Enum.max(chunk)}, retrying with smaller chunks"
          )

          # If chunk fails, try again with half the actual chunk size
          next_chunk_size = div(min(current_chunk_size, length(chunk)), 2)

          # credo:disable-for-lines:4 Credo.Check.Refactor.Nesting
          case fetch_receipts_with_fallback(chunk, json_rpc_named_arguments, next_chunk_size, original_chunk_size) do
            {:ok, chunk_receipts} -> {:cont, {:ok, acc ++ chunk_receipts}}
            {:error, chunk_reason} -> {:halt, {:error, {:chunk_failed, chunk_reason, reason}}}
          end
      end
    end)
  end

  # Fetches transaction receipts individually for a single block using eth_getTransactionReceipt.
  #
  # This function is used as a fallback when eth_getBlockReceipts fails for a block. It:
  # 1. Retrieves the block with its transactions from the database
  # 2. Extracts transaction hashes from the block
  # 3. Splits transactions into chunks based on the chunk size
  # 4. Fetches receipts for each chunk of transactions using eth_getTransactionReceipt
  #
  # ## Parameters
  # - `block_number`: The number of the block to fetch receipts for
  # - `json_rpc_named_arguments`: Configuration for JSON-RPC connection
  # - `chunk_size`: Maximum number of transactions to fetch receipts for in a single batch
  #
  # ## Returns
  # - `{:ok, receipts}` with list of successfully fetched receipts
  # - `{:error, reason}` if fetching any receipt fails
  @spec fetch_individual_receipts(
          non_neg_integer(),
          EthereumJSONRPC.json_rpc_named_arguments(),
          non_neg_integer()
        ) :: {:ok, [map()]} | {:error, any()}
  defp fetch_individual_receipts(block_number, json_rpc_named_arguments, chunk_size) do
    log_warning("Falling back to individual receipt fetching for block #{block_number}")

    with [block] <- ArbitrumDbUtils.rollup_blocks([block_number]),
         transaction_params when is_list(transaction_params) <-
           Enum.map(block.transactions, fn tx ->
             %{
               # defining the gas is required for the receipt to be fetched
               # but actually not used
               gas: tx.gas,
               hash: Hash.to_string(tx.hash)
             }
           end) do
      transaction_params
      |> Enum.chunk_every(chunk_size)
      |> Enum.reduce_while({:ok, []}, fn chunk, {:ok, acc} ->
        case Receipts.fetch(chunk, json_rpc_named_arguments) do
          {:ok, %{receipts: receipts}} -> {:cont, {:ok, acc ++ receipts}}
          {:error, reason} -> {:halt, {:error, reason}}
        end
      end)
    else
      # It is assumed that this branch is unreachable, as there is a check for
      # `indexed_blocks?` above in the stack
      [] -> {:error, :block_not_found}
    end
  end

  # Updates `Explorer.Chain.Block` and `Explorer.Chain.Transaction` records in the
  # database with Arbitrum-specific data.
  #
  # Processes lists of blocks and transaction receipts, updating their respective
  # database records with Arbitrum L2-specific information in a single transaction.
  #
  # ## Parameters
  # - `blocks`: List of maps containing Arbitrum block data with `hash`,
  #   `send_count`, `send_root`, and `l1_block_number`
  # - `receipts`: List of maps containing transaction data with `transaction_hash`
  #   and `gas_used_for_l1`
  #
  # ## Returns
  # - `:ok` when the database transaction succeeds
  # - `:error` when the database transaction fails
  @spec update_db(
          [
            %{
              :hash => EthereumJSONRPC.hash(),
              :send_count => non_neg_integer(),
              :send_root => EthereumJSONRPC.hash(),
              :l1_block_number => non_neg_integer(),
              optional(atom()) => any()
            }
          ],
          [
            %{
              :transaction_hash => EthereumJSONRPC.hash(),
              :gas_used_for_l1 => non_neg_integer(),
              optional(atom()) => any()
            }
          ]
        ) :: :ok | :error
  defp update_db(blocks, receipts)

  defp update_db([], []), do: :ok

  defp update_db(blocks, receipts) do
    log_info("Updating DB records for #{length(blocks)} blocks and #{length(receipts)} transactions")

    multi =
      Multi.new()
      |> update_blocks(blocks)
      |> update_transactions(receipts)

    case Repo.transaction(multi) do
      {:ok, _} -> :ok
      {:error, _} -> :error
      {:error, _, _, _} -> :error
    end
  end

  # Groups updates of the DB for the `Explorer.Chain.Block` table.
  #
  # Takes a list of blocks and adds update operations to the `Ecto.Multi` struct
  # for updating `send_count`, `send_root`, `l1_block_number` values in
  # `Explorer.Chain.Block`. The actual database updates are performed later when
  # the `Ecto.Multi` is executed in a single DB transaction.
  #
  # ## Parameters
  # - `multi`: The `Ecto.Multi` struct to accumulate the update operations
  # - `blocks`: List of block maps containing `hash`, `send_count`, `send_root`,
  #   and `l1_block_number` values
  #
  # ## Returns
  # - The `Ecto.Multi` struct with the accumulated block update operations
  @spec update_blocks(Multi.t(), [
          %{
            :hash => EthereumJSONRPC.hash(),
            :send_count => non_neg_integer(),
            :send_root => EthereumJSONRPC.hash(),
            :l1_block_number => non_neg_integer(),
            optional(atom()) => any()
          }
        ]) :: Multi.t()
  defp update_blocks(multi, blocks)

  defp update_blocks(multi, []), do: multi

  defp update_blocks(multi, blocks) do
    blocks
    |> Enum.reduce(multi, fn block, multi_acc ->
      Multi.update_all(
        multi_acc,
        {:block, block.hash},
        from(b in RollupBlock, where: b.hash == ^block.hash),
        set: [
          send_count: block.send_count,
          send_root: block.send_root,
          l1_block_number: block.l1_block_number,
          updated_at: DateTime.utc_now()
        ]
      )
    end)
  end

  # Groups updates of the DB for the `Explorer.Chain.Transaction` table.
  #
  # Takes a list of transaction receipts and adds update operations to the `Ecto.Multi`
  # struct for updating `gas_used_for_l1` values in `Explorer.Chain.Transaction`. The
  # actual database updates are performed later when the `Ecto.Multi` is executed
  # in a single DB transaction.
  #
  # ## Parameters
  # - `multi`: The `Ecto.Multi` struct to accumulate the update operations
  # - `receipts`: List of transaction receipt maps containing `transaction_hash`
  #   and `gas_used_for_l1` values
  #
  # ## Returns
  # - The `Ecto.Multi` struct with the accumulated transaction update operations
  @spec update_transactions(Multi.t(), [
          %{
            :transaction_hash => EthereumJSONRPC.hash(),
            :gas_used_for_l1 => non_neg_integer(),
            optional(atom()) => any()
          }
        ]) :: Multi.t()
  defp update_transactions(multi, receipts)

  defp update_transactions(multi, []), do: multi

  defp update_transactions(multi, receipts) do
    receipts
    |> Enum.reduce(multi, fn receipt, multi_acc ->
      Multi.update_all(
        multi_acc,
        {:transaction, receipt.transaction_hash},
        from(t in RollupTransaction, where: t.hash == ^receipt.transaction_hash),
        set: [
          gas_used_for_l1: receipt.gas_used_for_l1,
          updated_at: DateTime.utc_now()
        ]
      )
    end)
  end
end
