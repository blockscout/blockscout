defmodule BlockScoutWeb.API.RPC.EpochView do
  use BlockScoutWeb, :view

  alias BlockScoutWeb.API.RPC.RPCView

  alias Explorer.Chain.Wei

  def render(json, %{rewards: rewards})
      when json in ~w(getvoterrewards.json getvalidatorrewards.json getgrouprewards.json) do
    RPCView.render("show.json", data: prepare_response(json, rewards))
  end

  def render(json, %{epoch: epoch})
      when json in ~w(getepoch.json) do
    RPCView.render("show.json", data: prepare_response(json, epoch))
  end

  def render("error.json", assigns) do
    RPCView.render("error.json", assigns)
  end

  def prepare_response("getvoterrewards.json", rewards),
    do: rewards |> wrap_rewards([{"groupAddress", :associated_account_hash}], :celo)

  def prepare_response("getvalidatorrewards.json", rewards),
    do: rewards |> wrap_rewards([{"groupAddress", :associated_account_hash}], :cusd)

  def prepare_response("getgrouprewards.json", rewards),
    do: rewards |> wrap_rewards([{"validatorAddress", :associated_account_hash}], :cusd)

  def prepare_response("getepoch.json", nil),
    do: nil

  def prepare_response("getepoch.json", epoch),
    do: %{
      "blockNumber" => to_string(epoch.block_number),
      "blockHash" => to_string(epoch.block_hash),
      "validatorTargetEpochRewards" => to_string(epoch.validator_target_epoch_rewards),
      "voterTargetEpochRewards" => to_string(epoch.voter_target_epoch_rewards),
      "communityTargetEpochRewards" => to_string(epoch.community_target_epoch_rewards),
      "carbonOffsettingTargetEpochRewards" => to_string(epoch.carbon_offsetting_target_epoch_rewards),
      "targetTotalSupply" => to_string(epoch.target_total_supply),
      "rewardsMultiplier" => to_string(epoch.rewards_multiplier),
      "rewardsMultiplierMax" => to_string(epoch.rewards_multiplier_max),
      "rewardsMultiplierUnder" => to_string(epoch.rewards_multiplier_under),
      "rewardsMultiplierOver" => to_string(epoch.rewards_multiplier_over),
      "targetVotingYield" => to_string(epoch.target_voting_yield),
      "targetVotingYieldMax" => to_string(epoch.target_voting_yield_max),
      "targetVotingYieldAdjustmentFactor" => to_string(epoch.target_voting_yield_adjustment_factor),
      "targetVotingFraction" => to_string(epoch.target_voting_fraction),
      "votingFraction" => to_string(epoch.voting_fraction),
      "totalLockedGold" => to_string(epoch.total_locked_gold),
      "totalNonVoting" => to_string(epoch.total_non_voting),
      "totalVotes" => to_string(epoch.total_votes),
      "electableValidatorsMax" => to_string(epoch.electable_validators_max),
      "reserveGoldBalance" => to_string(epoch.reserve_gold_balance),
      "goldTotalSupply" => to_string(epoch.gold_total_supply),
      "stableUsdTotalSupply" => to_string(epoch.stable_usd_total_supply),
      "reserveBolster" => to_string(epoch.reserve_bolster)
    }

  def wrap_rewards(rewards, meta, currency) do
    %{
      totalRewardAmounts: rewards.total_amount |> prepare_amounts(currency),
      totalRewardCount: to_string(rewards.total_count),
      rewards: Enum.map(rewards.rewards, fn reward -> prepare_rewards_response_item(reward, meta, currency) end)
    }
  end

  defp extract_locked_and_activated_gold_wei(%{account_locked_gold: nil, account_activated_gold: nil}), do: {nil, nil}

  defp extract_locked_and_activated_gold_wei(reward) do
    {:ok, reward_address_locked_gold_wei} = Wei.cast(reward.account_locked_gold)
    {:ok, reward_address_activated_gold_wei} = Wei.cast(reward.account_activated_gold)

    {reward_address_locked_gold_wei, reward_address_activated_gold_wei}
  end

  defp prepare_rewards_response_item(reward, meta, currency) do
    {reward_address_locked_gold_wei, reward_address_activated_gold_wei} = extract_locked_and_activated_gold_wei(reward)

    %{
      amounts: reward.amount |> prepare_amounts(currency),
      blockHash: to_string(reward.block_hash),
      blockNumber: to_string(reward.block_number),
      blockTimestamp: reward.date |> DateTime.to_iso8601(),
      epochNumber: to_string(reward.epoch_number),
      meta:
        Map.new(Enum.map(meta, fn {meta_key, reward_key} -> {meta_key, to_string(Map.get(reward, reward_key))} end)),
      rewardAddress: to_string(reward.account_hash),
      rewardAddressVotingGold: reward_address_activated_gold_wei |> to_celo_wei_amount,
      rewardAddressLockedGold: reward_address_locked_gold_wei |> to_celo_wei_amount
    }
  end

  defp prepare_amounts(amount, :celo), do: amount |> to_celo_wei_amount
  defp prepare_amounts(amount, :cusd), do: amount |> to_currency_amount("cUSD")

  defp to_celo_wei_amount(nil = _wei),
    do: %{
      celo: "unknown",
      wei: "unknown"
    }

  defp to_celo_wei_amount(wei),
    do: %{
      celo: to_string(wei |> Wei.to(:ether)),
      wei: to_string(wei)
    }

  defp to_currency_amount(amount, currency_symbol),
    do: %{
      currency_symbol => to_string(amount |> Wei.to(:ether))
    }
end
