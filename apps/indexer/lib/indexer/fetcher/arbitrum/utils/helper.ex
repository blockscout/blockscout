defmodule Indexer.Fetcher.Arbitrum.Utils.Helper do
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
        ) :: %{
          binary() => %{
            :block => non_neg_integer(),
            :timestamp => DateTime.t(),
            :status => :unfinalized | :finalized,
            optional(any()) => any()
          }
        }
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
end
