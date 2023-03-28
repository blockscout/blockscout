defmodule Explorer.Celo.EpochUtil do
  @moduledoc """
  Utilities epoch related functionality
  """
  alias Explorer.Celo.Util
  alias Explorer.Chain
  alias Explorer.Chain.{CeloAccountEpoch, CeloElectionRewards, Wei}

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

  def get_address_summary(address) do
    {validator_or_group_sum, voting_sum} = get_sums(address)

    last_account_epoch = CeloAccountEpoch.last_for_address(address.hash)
    {locked_gold, vote_activated_gold} = last_account_epoch |> calculate_locked_and_vote_activated_gold()

    pending_gold = Chain.fetch_sum_available_celo_unlocked_for_address(address.hash)

    %{
      validator_or_group_sum: validator_or_group_sum,
      voting_sum: voting_sum,
      locked_gold: locked_gold,
      vote_activated_gold: vote_activated_gold,
      pending_gold: pending_gold
    }
  end

  defp get_sums(%Chain.Address{celo_account: %Ecto.Association.NotLoaded{}, hash: address_hash}) do
    {nil, CeloElectionRewards.get_rewards_sum_for_account(address_hash)}
  end

  defp get_sums(%Chain.Address{celo_account: nil, hash: address_hash}) do
    {nil, CeloElectionRewards.get_rewards_sum_for_account(address_hash)}
  end

  defp get_sums(address) do
    case address.celo_account.account_type do
      "normal" -> {nil, CeloElectionRewards.get_rewards_sum_for_account(address.hash)}
      type -> CeloElectionRewards.get_rewards_sums_for_account(address.hash, type)
    end
  end

  defp calculate_locked_and_vote_activated_gold(nil) do
    {:ok, zero_wei} = Wei.cast(0)
    {zero_wei, zero_wei}
  end

  defp calculate_locked_and_vote_activated_gold(account_epoch),
    do: {account_epoch.total_locked_gold, Wei.sub(account_epoch.total_locked_gold, account_epoch.nonvoting_locked_gold)}
end
