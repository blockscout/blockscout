defmodule Explorer.Chain.Celo.Helper do
  @moduledoc """
  Common helper functions for Celo.
  """

  @blocks_per_epoch 17_280

  def blocks_per_epoch, do: @blocks_per_epoch

  defguard is_epoch_block(block_number)
           when is_integer(block_number) and
                  rem(block_number, @blocks_per_epoch) == 0

  @spec epoch_block?(non_neg_integer) :: boolean
  def epoch_block?(block_number), do: rem(block_number, @blocks_per_epoch) == 0

  @spec block_number_to_epoch_number(block_number :: non_neg_integer) :: non_neg_integer
  def block_number_to_epoch_number(block_number) do
    (block_number / @blocks_per_epoch) |> Float.ceil() |> trunc()
  end
end
