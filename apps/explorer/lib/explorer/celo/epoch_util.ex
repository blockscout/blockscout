defmodule Explorer.Celo.EpochUtil do
  @moduledoc """
  Utilities epoch related functionality
  """
  alias Explorer.Celo.Util
  alias Explorer.Chain
  alias Explorer.Chain.CeloElectionRewards

  def epoch_by_block_number(bn) do
    div(bn, 17_280)
  end

  def is_epoch_block?(bn) do
    rem(bn, 17_280) == 0
  end

  def calculate_epoch_transaction_count_for_block(_, nil), do: 0

  def calculate_epoch_transaction_count_for_block(bn, epoch_rewards) do
    if is_epoch_block?(bn) do
      additional_transactions_count =
        if Decimal.cmp(epoch_rewards.reserve_bolster.value, 0) == :gt do
          3
        else
          2
        end

      CeloElectionRewards.get_epoch_transaction_count_for_block(bn) + additional_transactions_count
    else
      0
    end
  end

  def get_reward_currency_address_hash(reward_type) do
    with {:ok, address_string} <-
           Util.get_address(
             case reward_type do
               "voter" -> "GoldToken"
               _ -> "StableToken"
             end
           ),
         {:ok, address_hash} <- Chain.string_to_address_hash(address_string) do
      address_hash
    end
  end
end
