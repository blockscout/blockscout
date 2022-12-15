defmodule Explorer.Celo.EpochUtil do
  @moduledoc """
  Utilities epoch related functionality
  """
  alias Explorer.Celo.Util
  alias Explorer.Chain
  alias Explorer.Chain.CeloElectionRewards

  def epoch_by_block_number(bn) when rem(bn, 17_280) == 0, do: div(bn, blocks_per_epoch())
  def epoch_by_block_number(bn), do: div(bn, blocks_per_epoch()) + 1

  def is_epoch_block?(bn) do
    rem(bn, blocks_per_epoch()) == 0
  end

  def calculate_epoch_transaction_count_for_block(_, nil), do: 0

  def calculate_epoch_transaction_count_for_block(bn, epoch_rewards) do
    if is_epoch_block?(bn) do
      additional_transactions_count =
        if Decimal.compare(epoch_rewards.reserve_bolster.value, 0) == :gt do
          3
        else
          2
        end

      CeloElectionRewards.get_epoch_transaction_count_for_block(bn) + additional_transactions_count
    else
      0
    end
  end

  def round_to_closest_epoch_block_number(nil = _block_number, _), do: nil

  def round_to_closest_epoch_block_number(block_number, :up),
    do: ceil(block_number / blocks_per_epoch()) * blocks_per_epoch()

  def round_to_closest_epoch_block_number(block_number, :down) when block_number < 17_280, do: blocks_per_epoch()

  def round_to_closest_epoch_block_number(block_number, :down),
    do: floor(block_number / blocks_per_epoch()) * blocks_per_epoch()

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

  def blocks_per_epoch, do: 17_280
end
