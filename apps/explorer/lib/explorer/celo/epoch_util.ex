defmodule Explorer.Celo.EpochUtil do
  @moduledoc """
  Utilities epoch related functionality
  """

  def epoch_by_block_number(bn) do
    div(bn, 17_280)
  end

  def is_epoch_block?(bn) do
    rem(bn, 17_280) == 0
  end
end
