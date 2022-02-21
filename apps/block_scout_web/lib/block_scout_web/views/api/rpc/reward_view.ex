defmodule BlockScoutWeb.API.RPC.RewardView do
  use BlockScoutWeb, :view

  alias BlockScoutWeb.API.RPC.RPCView

  def render("getvoterrewardsforgroup.json", %{rewards: rewards}) do
    prepared_rewards = prepare_rewards_for_group(rewards)

    RPCView.render("show.json", data: prepared_rewards)
  end

  def render("getvoterrewards.json", %{rewards: rewards}) do
    prepared_rewards = prepare_rewards_for_all_groups(rewards)

    RPCView.render("show.json", data: prepared_rewards)
  end

  def render("error.json", assigns) do
    RPCView.render("error.json", assigns)
  end

  defp prepare_rewards_for_group(rewards) do
    %{
      total: to_string(rewards.total),
      rewards: Enum.map(rewards.rewards, &prepare_reward_for_group(&1))
    }
  end

  defp prepare_reward_for_group(reward) do
    %{
      amount: to_string(reward.amount),
      blockHash: to_string(reward.block_hash),
      blockNumber: to_string(reward.block_number),
      date: reward.date,
      epochNumber: to_string(reward.epoch_number)
    }
  end

  defp prepare_rewards_for_all_groups(rewards) do
    %{
      totalRewardCelo: to_string(rewards.total_reward_celo),
      voterAccount: to_string(rewards.voter_account),
      from: to_string(rewards.from),
      to: to_string(rewards.to),
      rewards: Enum.map(rewards.rewards, &prepare_reward_for_all_groups(&1))
    }
  end

  defp prepare_reward_for_all_groups(reward) do
    %{
      amount: to_string(reward.amount),
      blockHash: to_string(reward.block_hash),
      blockNumber: to_string(reward.block_number),
      date: reward.date,
      epochNumber: to_string(reward.epoch_number),
      group: to_string(reward.group)
    }
  end
end
