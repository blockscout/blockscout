defmodule BlockScoutWeb.API.RPC.RewardView do
  use BlockScoutWeb, :view

  alias BlockScoutWeb.API.RPC.RPCView

  def render("getvoterrewardsforgroup.json", %{rewards: rewards}) do
    prepared_rewards = prepare_rewards_for_group(rewards)

    RPCView.render("show.json", data: prepared_rewards)
  end

  def render(json, %{rewards: rewards}) when json in ~w(getvoterrewards.json getvalidatorrewards.json) do
    prepared_rewards =
      if Map.has_key?(rewards, :account) do
        prepare_generic_rewards(rewards)
      else
        prepare_generic_rewards_multiple_accounts(rewards)
      end

    RPCView.render("show.json", data: prepared_rewards)
  end

  def render("getvalidatorgrouprewards.json", %{rewards: rewards}) do
    prepared_rewards =
      if Map.has_key?(rewards, :group) do
        prepare_group_rewards(rewards)
      else
        prepare_group_rewards_multiple_accounts(rewards)
      end

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

  defp prepare_generic_rewards(rewards) do
    %{
      totalRewardCelo: to_string(rewards.total_reward_celo),
      account: to_string(rewards.account),
      from: to_string(rewards.from),
      to: to_string(rewards.to),
      rewards: Enum.map(rewards.rewards, &prepare_generic_reward(&1))
    }
  end

  defp prepare_generic_rewards_multiple_accounts(rewards) do
    %{
      totalRewardCelo: to_string(rewards.total_reward_celo),
      from: to_string(rewards.from),
      to: to_string(rewards.to),
      rewards: Enum.map(rewards.rewards, &prepare_generic_reward_multiple_accounts(&1))
    }
  end

  defp prepare_group_rewards(rewards) do
    %{
      totalRewardCelo: to_string(rewards.total_reward_celo),
      from: to_string(rewards.from),
      group: to_string(rewards.group),
      to: to_string(rewards.to),
      rewards: Enum.map(rewards.rewards, &prepare_group_epoch_rewards(&1))
    }
  end

  defp prepare_group_rewards_multiple_accounts(rewards) do
    %{
      totalRewardCelo: to_string(rewards.total_reward_celo),
      from: to_string(rewards.from),
      to: to_string(rewards.to),
      rewards: Enum.map(rewards.rewards, &prepare_group_epoch_rewards_multiple_accounts(&1))
    }
  end

  defp prepare_generic_reward(reward) do
    %{
      amount: to_string(reward.amount),
      blockHash: to_string(reward.block_hash),
      blockNumber: to_string(reward.block_number),
      date: reward.date,
      epochNumber: to_string(reward.epoch_number),
      group: to_string(reward.group)
    }
  end

  defp prepare_generic_reward_multiple_accounts(reward) do
    %{
      account: to_string(reward.account),
      amount: to_string(reward.amount),
      blockHash: to_string(reward.block_hash),
      blockNumber: to_string(reward.block_number),
      date: reward.date,
      epochNumber: to_string(reward.epoch_number),
      group: to_string(reward.group)
    }
  end

  defp prepare_group_epoch_rewards(reward) do
    %{
      amount: to_string(reward.amount),
      blockHash: to_string(reward.block_hash),
      blockNumber: to_string(reward.block_number),
      date: reward.date,
      epochNumber: to_string(reward.epoch_number),
      validator: to_string(reward.validator)
    }
  end

  defp prepare_group_epoch_rewards_multiple_accounts(reward) do
    %{
      amount: to_string(reward.amount),
      blockHash: to_string(reward.block_hash),
      blockNumber: to_string(reward.block_number),
      date: reward.date,
      epochNumber: to_string(reward.epoch_number),
      group: to_string(reward.group),
      validator: to_string(reward.validator)
    }
  end
end
