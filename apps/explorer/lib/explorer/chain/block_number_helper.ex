# credo:disable-for-this-file
defmodule Explorer.Chain.BlockNumberHelper do
  @moduledoc """
  Functions to operate with block numbers based on null round heights (applicable for CHAIN_TYPE=filecoin)
  """
  use Utils.CompileTimeEnvHelper, chain_type: [:explorer, :chain_type]

  def previous_block_number(number), do: neighbor_block_number(number, :previous)

  def next_block_number(number), do: neighbor_block_number(number, :next)

  case @chain_type do
    :filecoin ->
      def null_rounds_count, do: Explorer.Chain.NullRoundHeight.total()

      defp neighbor_block_number(number, direction),
        do: Explorer.Chain.NullRoundHeight.neighbor_block_number(number, direction)

    _ ->
      def null_rounds_count, do: 0
      defp neighbor_block_number(number, direction), do: move_by_one(number, direction)
  end

  def move_by_one(number, :previous), do: number - 1
  def move_by_one(number, :next), do: number + 1
end
