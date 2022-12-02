defmodule BlockScoutWeb.API.RPC.RewardView do
  use BlockScoutWeb, :view

  alias BlockScoutWeb.API.RPC.RPCView
  alias Explorer.Celo.EpochUtil

  def render("getvoterrewardsforgroup.json", %{rewards: rewards}) do
    prepared_rewards = prepare_voter_rewards_for_group(rewards)

    RPCView.render("show.json", data: prepared_rewards)
  end

  def render(json, %{rewards: rewards}) when json in ~w(getvoterrewards.json getvalidatorrewards.json) do
    prepared_rewards = prepare_generic_rewards(rewards)

    RPCView.render("show.json", data: prepared_rewards)
  end

  def render("getvalidatorgrouprewards.json", %{rewards: rewards}) do
    prepared_rewards = prepare_group_rewards(rewards)

    RPCView.render("show.json", data: prepared_rewards)
  end

  def render("error.json", assigns) do
    RPCView.render("error.json", assigns)
  end

  defp prepare_voter_rewards_for_group(rewards) do
    %{
      total: to_string(rewards.total),
      rewards: Enum.map(rewards.rewards, &prepare_voter_reward_for_group(&1))
    }
  end

  defp prepare_voter_reward_for_group(reward) do
    %{
      amount: to_string(reward.amount),
      blockNumber: to_string(reward.block_number),
      date: reward.block_timestamp,
      epochNumber: to_string(EpochUtil.epoch_by_block_number(reward.block_number))
    }
  end

  defp prepare_generic_rewards(rewards) do
    %{
      totalRewardCelo: to_string(rewards.total_reward_celo),
      from: to_string(rewards.from),
      to: to_string(rewards.to),
      rewards: Enum.map(rewards.rewards, &prepare_generic_reward(&1))
    }
  end

  defp prepare_group_rewards(rewards) do
    %{
      totalRewardCelo: to_string(rewards.total_reward_celo),
      from: to_string(rewards.from),
      to: to_string(rewards.to),
      rewards: Enum.map(rewards.rewards, &prepare_group_epoch_rewards(&1))
    }
  end

  defp prepare_generic_reward(reward) do
    %{
      account: to_string(reward.account_hash),
      amount: to_string(reward.amount),
      blockNumber: to_string(reward.block_number),
      date: reward.block_timestamp,
      epochNumber: to_string(EpochUtil.epoch_by_block_number(reward.block_number)),
      group: to_string(reward.associated_address.celo_account.name)
    }
  end

  defp prepare_group_epoch_rewards(reward) do
    %{
      amount: to_string(reward.amount),
      blockNumber: to_string(reward.block_number),
      date: reward.block_timestamp,
      epochNumber: to_string(EpochUtil.epoch_by_block_number(reward.block_number)),
      group: to_string(reward.account_hash),
      validator: to_string(reward.associated_address.celo_account.name)
    }
  end
end
