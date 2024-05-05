defmodule Explorer.Chain.Celo.Helper do
  @moduledoc """
  Common helper functions for Celo.
  """

  @blocks_per_epoch 17_280

  def blocks_per_epoch, do: @blocks_per_epoch

  def epoch_block?(block_number), do: rem(block_number, @blocks_per_epoch) == 0
end
