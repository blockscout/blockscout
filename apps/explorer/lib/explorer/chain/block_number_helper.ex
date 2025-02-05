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

  @spec get_null_rounds_count() :: non_neg_integer()
  @spec neighbor_block_number(non_neg_integer(), :previous | :next) :: non_neg_integer()

  case @chain_type do
    :filecoin ->
      # Returns the total count of null rounds in the blockchain.
      defp get_null_rounds_count, do: Explorer.Chain.NullRoundHeight.total()

      # Determines the actual neighboring block number taking into account null rounds.
      defp neighbor_block_number(number, direction),
        do: Explorer.Chain.NullRoundHeight.neighbor_block_number(number, direction)

    _ ->
      defp get_null_rounds_count, do: 0

      # Determines the adjacent block number
      # Returns the adjacent block number by incrementing/decrementing by 1. Note that
      # this simple approach differs from Filecoin which handles null rounds. Looks like
      # only blocks with consensus `true` must be taken into account here as well.
      defp neighbor_block_number(number, direction), do: move_by_one(number, direction)
  end

  @spec move_by_one(non_neg_integer(), :previous | :next) :: non_neg_integer()
  def move_by_one(number, :previous), do: number - 1
  def move_by_one(number, :next), do: number + 1
end
