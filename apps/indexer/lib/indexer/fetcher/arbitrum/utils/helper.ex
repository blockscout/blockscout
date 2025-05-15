defmodule Indexer.Fetcher.Arbitrum.Utils.Helper do
  alias Explorer.Chain.Arbitrum.LifecycleTransaction
  alias Explorer.Chain.Cache.BackgroundMigrations

  import EthereumJSONRPC, only: [quantity_to_integer: 1]
  import Indexer.Fetcher.Arbitrum.Utils.Logging, only: [log_info: 1]

  @moduledoc """
  Provides utility functions to support the handling of Arbitrum-specific data fetching and processing in the indexer.
  """

  @doc """
    Updates the data for a task of the batches fetcher.

    This function takes the current state, a task tag, and a map of updates, then
    merges the updates with the existing task data for that tag.

    ## Parameters
    - `state`: The current state map containing task_data
    - `task_tag`: The atom key for the task (e.g. :new_executions or :historical_executions)
    - `updates`: Map of values to merge with the current task data

    ## Returns
    - Updated state with merged task data

    ## Examples

        iex> state = %{task_data: %{new_executions: %{start_block: 100}}}
        iex> update_fetcher_task_data(state, :new_executions, %{start_block: 200})
        %{task_data: %{new_executions: %{start_block: 200}}}
  """
  @spec update_fetcher_task_data(
          %{:task_data => %{optional(atom()) => map()}, optional(any()) => any()},
          atom(),
          map()
        ) :: %{:task_data => %{optional(atom()) => map()}, optional(any()) => any()}
  def update_fetcher_task_data(%{task_data: data} = state, task_tag, updates)
      when is_atom(task_tag) and is_map(updates) do
    %{state | task_data: %{data | task_tag => Map.merge(data[task_tag], updates)}}
  end

  @doc """
  Checks if the unconfirmed blocks index is ready for use.

  This function verifies if the heavy DB index operation for creating the unconfirmed blocks
  index has been completed. This check is necessary to avoid running queries that depend on
  this index before it's fully created, which could lead to performance issues.

  ## Returns
  - `true` if the index creation is complete
  - `false` if the index is still being created or not started yet
  """
  @spec unconfirmed_blocks_index_ready?() :: boolean()
  def unconfirmed_blocks_index_ready? do
    BackgroundMigrations.get_heavy_indexes_create_arbitrum_batch_l2_blocks_unconfirmed_blocks_index_finished()
  end

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
    - `lifecycle_transactions`: A map where each key is a transaction identifier, and the value is
      a map containing at least the block number (`:block`).
    - `blocks_to_ts`: A map linking block numbers to their corresponding timestamps.
    - `track_finalization?`: A boolean flag indicating whether to mark transactions
      as unfinalized or finalized.

    ## Returns
    - An updated map of the same structure as `lifecycle_transactions` but with each transaction extended to include:
      - `timestamp`: The timestamp of the block in which the transaction is included.
      - `status`: Either `:unfinalized` if `track_finalization?` is `true`, or `:finalized` otherwise.
  """
  @spec extend_lifecycle_transactions_with_ts_and_status(
          %{binary() => %{:block => non_neg_integer(), optional(any()) => any()}},
          %{non_neg_integer() => DateTime.t()},
          boolean()
        ) :: %{binary() => LifecycleTransaction.to_import()}
  def extend_lifecycle_transactions_with_ts_and_status(lifecycle_transactions, blocks_to_ts, track_finalization?)
      when is_map(lifecycle_transactions) and is_map(blocks_to_ts) and is_boolean(track_finalization?) do
    lifecycle_transactions
    |> Map.keys()
    |> Enum.reduce(%{}, fn transaction_key, updated_transactions ->
      Map.put(
        updated_transactions,
        transaction_key,
        Map.merge(lifecycle_transactions[transaction_key], %{
          timestamp: blocks_to_ts[lifecycle_transactions[transaction_key].block_number],
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
    logs the update, and returns `{:updated, updated_transaction}`.

    ## Parameters
    - `transaction`: The lifecycle transaction to compare and potentially update.
    - `{new_block_num, new_ts}`: A tuple containing the new block number and timestamp.
    - `transaction_type_str`: A string describing the type of the transaction for logging purposes.

    ## Returns
    - `{:same, nil}` if the transaction block number and timestamp are the same as the provided values.
    - `{:updated, updated_transaction}` if the transaction was updated with the new block number and timestamp.
  """
  @spec compare_lifecycle_transaction_and_update(
          LifecycleTransaction.to_import(),
          {non_neg_integer(), DateTime.t()},
          String.t()
        ) :: {:same, nil} | {:updated, LifecycleTransaction.to_import()}
  def compare_lifecycle_transaction_and_update(transaction, {new_block_num, new_ts}, transaction_type_str) do
    if transaction.block_number == new_block_num and DateTime.compare(transaction.timestamp, new_ts) == :eq do
      {:same, nil}
    else
      log_info(
        "The #{transaction_type_str} transaction 0x#{transaction.hash |> Base.encode16(case: :lower)} will be updated with the new block number and timestamp"
      )

      {:updated,
       Map.merge(transaction, %{
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

  @doc """
    Converts a message ID to its hashed hexadecimal string representation.

    This function takes a message ID (either as an integer or a hexadecimal string),
    concatenates it with 256 zero bits, computes a hash of the concatenation, and
    then converts the resulting hash to a hexadecimal string with a "0x" prefix.

    ## Parameters
    - `message_id`: The message ID to be hashed and converted. Can be either a
      non-negative integer or a "0x"-prefixed hexadecimal string.

    ## Returns
    - A string representing the hashed message ID in hexadecimal format, prefixed
      with "0x".

    ## Examples

        iex> get_hashed_message_id_as_hex_str(1490421)
        "0x9d1614591a3e0ba8854206a716e49ffdffc679131820fa815b989fdef9e5554d"

        iex> get_hashed_message_id_as_hex_str("0x000000000000000000000000000000000000000000000000000000000016bdf5")
        "0x9d1614591a3e0ba8854206a716e49ffdffc679131820fa815b989fdef9e5554d"
  """
  @spec get_hashed_message_id_as_hex_str(non_neg_integer() | binary()) :: String.t()
  def get_hashed_message_id_as_hex_str(message_id) do
    message_id
    |> hash_for_message_id()
    |> bytes_to_hex_str()
  end

  # Calculates the hash for a given message ID.
  #
  # This function computes a 256-bit Keccak hash of the message ID. For integer
  # inputs, it concatenates the 256-bit message ID with 256 zero bits before
  # hashing. For hexadecimal string inputs, it first converts the string to an
  # integer.
  #
  # ## Parameters
  # - `message_id`: Either a non-negative integer or a "0x"-prefixed hexadecimal
  #   string of 66 characters (including the "0x" prefix).
  #
  # ## Returns
  # - A binary representing the 256-bit Keccak hash of the processed message ID.
  @spec hash_for_message_id(non_neg_integer() | binary()) :: binary()
  defp hash_for_message_id(message_id) when is_integer(message_id) do
    # As per https://github.com/OffchainLabs/nitro/blob/849348e10cf1d9c023f4748dc1211bd363422485/arbos/parse_l2.go#L40
    (<<message_id::size(256)>> <> <<0::size(256)>>)
    |> ExKeccak.hash_256()
  end

  defp hash_for_message_id(message_id) when is_binary(message_id) and byte_size(message_id) == 66 do
    hash_for_message_id(quantity_to_integer(message_id))
  end
end
