defmodule Explorer.Chain.Celo.Helper do
  @moduledoc """
  Common helper functions for Celo.
  """

  alias Explorer.Chain.Block

  @blocks_per_epoch 17_280

  def blocks_per_epoch, do: @blocks_per_epoch

  defguard is_epoch_block_number(block_number)
           when is_integer(block_number) and
                  block_number >= 0 and
                  rem(block_number, @blocks_per_epoch) == 0

  @spec epoch_block_number?(block_number :: Block.block_number()) :: boolean
  def epoch_block_number?(block_number)
      when is_epoch_block_number(block_number),
      do: true

  def epoch_block_number?(_), do: false

  @spec block_number_to_epoch_number(block_number :: Block.block_number()) :: non_neg_integer
  def block_number_to_epoch_number(block_number) when is_integer(block_number) do
    (block_number / @blocks_per_epoch) |> Float.ceil() |> trunc()
  end
end
