defmodule Explorer.Celo.EpochUtil do
  @moduledoc """
  Utilities epoch related functionality
  """
  alias Explorer.Chain.CeloElectionRewards

  def epoch_by_block_number(bn) do
    div(bn, 17_280)
  end

  def is_epoch_block?(bn) do
    rem(bn, 17_280) == 0
  end

  def calculate_epoch_transaction_count_for_block(bn, nil = _epoch_rewards), do: 0

  def calculate_epoch_transaction_count_for_block(bn, _epoch_rewards) do
    if is_epoch_block?(bn) do
      CeloElectionRewards.get_epoch_transaction_count_for_block(bn) + 2
    else
      0
    end
  end
end
