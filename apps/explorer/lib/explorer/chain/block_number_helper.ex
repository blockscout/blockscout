# credo:disable-for-this-file
defmodule Explorer.Chain.BlockNumberHelper do
  @moduledoc """
  Provides helper functions for navigating block numbers in a blockchain.

  For Filecoin chains, this module handles the concept of null rounds - epochs where
  no blocks were produced. It helps traverse the blockchain sequence by accounting
  for these gaps in block heights.

  For other chain types, it provides standard block number navigation without
  considering null rounds.
  """

  use Utils.CompileTimeEnvHelper, chain_type: [:explorer, :chain_type]

  @doc """
    Returns the previous block number in the blockchain sequence.

    For Filecoin chain type, accounts for null rounds when determining the previous
    block number. For other chain types, simply returns the number decremented by
    one.

    ## Parameters
    - `number`: The reference block height

    ## Returns
    - The previous block number, accounting for null rounds in Filecoin chain
  """
  @spec previous_block_number(non_neg_integer()) :: non_neg_integer()
  def previous_block_number(number), do: neighbor_block_number(number, :previous)

  @doc """
    Returns the next block number in the blockchain sequence.

    For Filecoin chain type, accounts for null rounds when determining the next
    block number. For other chain types, simply returns the number incremented by
    one.

    ## Parameters
    - `number`: The reference block height

    ## Returns
    - The next block number, accounting for null rounds in Filecoin chain
  """
  @spec next_block_number(non_neg_integer()) :: non_neg_integer()
  def next_block_number(number), do: neighbor_block_number(number, :next)

  @doc """
    Returns the total count of null rounds in the blockchain.

    For Filecoin chain type, returns the actual count of null round heights stored
    in the database. For other chain types, always returns 0.

    ## Returns
    - Total number of null rounds in the blockchain
  """
  @spec null_rounds_count() :: non_neg_integer()
  def null_rounds_count, do: get_null_rounds_count()

  @doc """
    Finds the next valid block number that is not a null round.

    For Filecoin chain type, checks if the given block height represents a null round
    and searches for the next valid block in the specified direction. For other chain
    types, returns the input block number since null rounds do not exist.

    ## Parameters
    - `height`: The block height to check and find next valid block for
    - `direction`: Either `:previous` or `:next` to indicate search direction

    ## Returns
    - `{:ok, number}` where number is either the input height or the next valid
      block number
    - `{:error, :not_found}` if no valid block can be found in the specified direction
  """
  @spec find_next_non_null_round_block(non_neg_integer(), :previous | :next) ::
          {:ok, non_neg_integer()} | {:error, :not_found}
  def find_next_non_null_round_block(height, direction), do: do_find_next_non_null_round_block(height, direction)

  @spec get_null_rounds_count() :: non_neg_integer()
  @spec neighbor_block_number(non_neg_integer(), :previous | :next) :: non_neg_integer()
  @spec do_find_next_non_null_round_block(non_neg_integer(), :previous | :next) ::
          {:ok, non_neg_integer()} | {:error, :not_found}

  case @chain_type do
    :filecoin ->
      # Returns the total count of null rounds in the blockchain.
      defp get_null_rounds_count, do: Explorer.Chain.NullRoundHeight.total()

      # Determines the actual neighboring block number taking into account null rounds.
      defp neighbor_block_number(number, direction),
        do: Explorer.Chain.NullRoundHeight.neighbor_block_number(number, direction)

      # Checks if the current block number is a null round and finds the next non-null round block number.
      defp do_find_next_non_null_round_block(height, direction),
        do: Explorer.Chain.NullRoundHeight.find_next_non_null_round_block(height, direction)

    _ ->
      defp get_null_rounds_count, do: 0

      # Determines the adjacent block number
      # Returns the adjacent block number by incrementing/decrementing by 1. Note that
      # this simple approach differs from Filecoin which handles null rounds. Looks like
      # only blocks with consensus `true` must be taken into account here as well.
      defp neighbor_block_number(number, direction), do: move_by_one(number, direction)

      # For non-Filecoin chains, the concept of null rounds doesn't exist, so it
      # is assumed that the block number is always valid.
      defp do_find_next_non_null_round_block(block_number, _), do: {:ok, block_number}
  end

  @spec move_by_one(non_neg_integer(), :previous | :next) :: non_neg_integer()
  def move_by_one(number, :previous), do: number - 1
  def move_by_one(number, :next), do: number + 1
end
