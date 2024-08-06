defmodule Indexer.Fetcher.Arbitrum.Utils.Helper do
  alias Explorer.Chain.Arbitrum.LifecycleTransaction

  import Indexer.Fetcher.Arbitrum.Utils.Logging, only: [log_info: 1]

  @moduledoc """
  Provides utility functions to support the handling of Arbitrum-specific data fetching and processing in the indexer.
  """

  @doc """
    Increases a base duration by an amount specified in a map, if present.

    This function takes a map that may contain a duration key and a current duration value.
    If the map contains a duration, it is added to the current duration; otherwise, the
    current duration is returned unchanged.

    ## Parameters
    - `data`: A map that may contain a `:duration` key with its value representing
      the amount of time to add.
    - `cur_duration`: The current duration value, to which the duration from the map
      will be added if present.

    ## Returns
    - The increased duration.
  """
  @spec increase_duration(
          %{optional(:duration) => non_neg_integer(), optional(any()) => any()},
          non_neg_integer()
        ) :: non_neg_integer()
  def increase_duration(data, cur_duration)
      when is_map(data) and is_integer(cur_duration) and cur_duration >= 0 do
    if Map.has_key?(data, :duration) do
      data.duration + cur_duration
    else
      cur_duration
    end
  end

  @doc """
    Enriches lifecycle transaction entries with timestamps and status based on provided block information and finalization tracking.

    This function takes a map of lifecycle transactions and extends each entry with
    a timestamp (extracted from a corresponding map of block numbers to timestamps)
    and a status. The status is determined based on whether finalization tracking is enabled.

    ## Parameters
    - `lifecycle_txs`: A map where each key is a transaction identifier, and the value is
      a map containing at least the block number (`:block`).
    - `blocks_to_ts`: A map linking block numbers to their corresponding timestamps.
    - `track_finalization?`: A boolean flag indicating whether to mark transactions
      as unfinalized or finalized.

    ## Returns
    - An updated map of the same structure as `lifecycle_txs` but with each transaction extended to include:
      - `timestamp`: The timestamp of the block in which the transaction is included.
      - `status`: Either `:unfinalized` if `track_finalization?` is `true`, or `:finalized` otherwise.
  """
  @spec extend_lifecycle_txs_with_ts_and_status(
          %{binary() => %{:block => non_neg_integer(), optional(any()) => any()}},
          %{non_neg_integer() => DateTime.t()},
          boolean()
        ) :: %{binary() => LifecycleTransaction.to_import()}
  def extend_lifecycle_txs_with_ts_and_status(lifecycle_txs, blocks_to_ts, track_finalization?)
      when is_map(lifecycle_txs) and is_map(blocks_to_ts) and is_boolean(track_finalization?) do
    lifecycle_txs
    |> Map.keys()
    |> Enum.reduce(%{}, fn tx_key, updated_txs ->
      Map.put(
        updated_txs,
        tx_key,
        Map.merge(lifecycle_txs[tx_key], %{
          timestamp: blocks_to_ts[lifecycle_txs[tx_key].block_number],
          status:
            if track_finalization? do
              :unfinalized
            else
              :finalized
            end
        })
      )
    end)
  end

  @doc """
    Compares a lifecycle transaction with new block number and timestamp, and updates if necessary.

    This function checks if the given lifecycle transaction has the same block number
    and timestamp as the provided values. If they are the same, it returns `{:same, nil}`.
    If they differ, it updates the transaction with the new block number and timestamp,
    logs the update, and returns `{:updated, updated_tx}`.

    ## Parameters
    - `tx`: The lifecycle transaction to compare and potentially update.
    - `{new_block_num, new_ts}`: A tuple containing the new block number and timestamp.
    - `tx_type_str`: A string describing the type of the transaction for logging purposes.

    ## Returns
    - `{:same, nil}` if the transaction block number and timestamp are the same as the provided values.
    - `{:updated, updated_tx}` if the transaction was updated with the new block number and timestamp.
  """
  @spec compare_lifecycle_tx_and_update(
          LifecycleTransaction.to_import(),
          {non_neg_integer(), DateTime.t()},
          String.t()
        ) :: {:same, nil} | {:updated, LifecycleTransaction.to_import()}
  def compare_lifecycle_tx_and_update(tx, {new_block_num, new_ts}, tx_type_str) do
    if tx.block_number == new_block_num and DateTime.compare(tx.timestamp, new_ts) == :eq do
      {:same, nil}
    else
      log_info(
        "The #{tx_type_str} transaction 0x#{tx.hash |> Base.encode16(case: :lower)} will be updated with the new block number and timestamp"
      )

      {:updated,
       Map.merge(tx, %{
         block_number: new_block_num,
         timestamp: new_ts
       })}
    end
  end

  @doc """
    Converts a binary data to a hexadecimal string.

    ## Parameters
    - `data`: The binary data to convert to a hexadecimal string.

    ## Returns
    - A hexadecimal string representation of the input data.
  """
  @spec bytes_to_hex_str(binary()) :: String.t()
  def bytes_to_hex_str(data) do
    "0x" <> Base.encode16(data, case: :lower)
  end

  @doc """
    Executes a function over a specified block range in chunks.

    This function divides a block range into smaller chunks and executes the provided
    function for each chunk. It collects the results of each function execution and
    returns them as a list of tuples. Each tuple contains the start and end block numbers
    of the chunk and the result of the function execution for that chunk.

    If `halt_on_error` is set to `true` and the function returns anything other than
    `:ok` or `{:ok, ...}`, the execution halts. However, the result of the last function
    execution is still included in the resulting list.

    ## Parameters
    - `start_block`: The starting block number of the range.
    - `end_block`: The ending block number of the range.
    - `chunk_size`: The size of each chunk in terms of block numbers.
    - `func`: The function to execute for each chunk. The function should accept two
              arguments: the start and end block numbers of the chunk.
    - `halt_on_error` (optional): A boolean flag indicating whether to halt execution
                                  if an error occurs. Defaults to `false`.

    ## Returns
    - A list of tuples. Each tuple contains:
      - A tuple with the start and end block numbers of the chunk.
      - The result of the function execution for that chunk.

    ## Examples

        iex> execute_for_block_range_in_chunks(5, 25, 7, fn (start_block, end_block) ->
        ...>   {:ok, start_block, end_block}
        ...> end)
        [
          {{5, 11}, {:ok, 5, 11}},
          {{12, 18}, {:ok, 12, 18}},
          {{19, 25}, {:ok, 19, 25}}
        ]
  """
  @spec execute_for_block_range_in_chunks(
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer(),
          fun()
        ) :: [
          {{non_neg_integer(), non_neg_integer()}, any()}
        ]
  @spec execute_for_block_range_in_chunks(
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer(),
          fun(),
          boolean()
        ) :: [
          {{non_neg_integer(), non_neg_integer()}, any()}
        ]
  def execute_for_block_range_in_chunks(start_block, end_block, chunk_size, func, halt_on_error \\ false) do
    0..div(end_block - start_block, chunk_size)
    |> Enum.reduce_while([], fn i, res ->
      chunk_start = start_block + i * chunk_size
      chunk_end = min(chunk_start + chunk_size - 1, end_block)

      func_res = func.(chunk_start, chunk_end)
      acc_res = [{{chunk_start, chunk_end}, func_res} | res]

      case {halt_on_error, func_res} do
        {false, _} -> {:cont, acc_res}
        {true, :ok} -> {:cont, acc_res}
        {true, {:ok, _}} -> {:cont, acc_res}
        {true, _} -> {:halt, acc_res}
      end
    end)
    |> Enum.reverse()
  end
end
