defmodule Explorer.Staking.ContractReader do
  @moduledoc """
  Routines for batched fetching of information from POSDAO contracts.
  """

  alias Explorer.SmartContract.Reader

  def global_requests do
    [
      active_pools: {:staking, "getPools", []},
      epoch_end_block: {:staking, "stakingEpochEndBlock", []},
      epoch_number: {:staking, "stakingEpoch", []},
      epoch_start_block: {:staking, "stakingEpochStartBlock", []},
      inactive_pools: {:staking, "getPoolsInactive", []},
      min_candidate_stake: {:staking, "candidateMinStake", []},
      min_delegator_stake: {:staking, "delegatorMinStake", []},
      pools_likelihood: {:staking, "getPoolsLikelihood", []},
      pools_to_be_elected: {:staking, "getPoolsToBeElected", []},
      staking_allowed: {:staking, "areStakeAndWithdrawAllowed", []},
      token_contract_address: {:staking, "erc677TokenContract", []},
      unremovable_validator: {:validator_set, "unremovableValidator", []},
      validators: {:validator_set, "getValidators", []},
      validator_set_apply_block: {:validator_set, "validatorSetApplyBlock", []}
    ]
  end

  def active_delegators_request(staking_address, block_number) do
    [
      active_delegators: {:staking, "poolDelegators", [staking_address], block_number}
    ]
  end

  # args = [staking_epoch, delegator_staked, validator_staked, total_staked, pool_reward \\ 10_00000]
  def delegator_reward_request(args) do
    [
      delegator_share: {:block_reward, "delegatorShare", args}
    ]
  end

  def pool_staking_requests(staking_address, block_number) do
    [
      active_delegators: active_delegators_request(staking_address, block_number)[:active_delegators],
      inactive_delegators: {:staking, "poolDelegatorsInactive", [staking_address]},
      is_active: {:staking, "isPoolActive", [staking_address]},
      mining_address_hash: {:validator_set, "miningByStakingAddress", [staking_address]},
      self_staked_amount: {:staking, "stakeAmount", [staking_address, staking_address]},
      total_staked_amount: {:staking, "stakeAmountTotal", [staking_address]},
      validator_reward_percent: {:block_reward, "validatorRewardPercent", [staking_address]}
    ]
  end

  def pool_mining_requests(mining_address) do
    [
      are_delegators_banned: {:validator_set, "areDelegatorsBanned", [mining_address]},
      ban_reason: {:validator_set, "banReason", [mining_address]},
      banned_until: {:validator_set, "bannedUntil", [mining_address]},
      banned_delegators_until: {:validator_set, "bannedDelegatorsUntil", [mining_address]},
      is_banned: {:validator_set, "isValidatorBanned", [mining_address]},
      was_validator_count: {:validator_set, "validatorCounter", [mining_address]},
      was_banned_count: {:validator_set, "banCounter", [mining_address]}
    ]
  end

  def staker_requests(pool_staking_address, staker_address) do
    [
      max_ordered_withdraw_allowed: {:staking, "maxWithdrawOrderAllowed", [pool_staking_address, staker_address]},
      max_withdraw_allowed: {:staking, "maxWithdrawAllowed", [pool_staking_address, staker_address]},
      ordered_withdraw: {:staking, "orderedWithdrawAmount", [pool_staking_address, staker_address]},
      ordered_withdraw_epoch: {:staking, "orderWithdrawEpoch", [pool_staking_address, staker_address]},
      stake_amount: {:staking, "stakeAmount", [pool_staking_address, staker_address]}
    ]
  end

  def staking_by_mining_request(mining_address) do
    [
      staking_address: {:validator_set, "stakingByMiningAddress", [mining_address]}
    ]
  end

  def validator_min_reward_percent_request(epoch_number) do
    [
      value: {:block_reward, "validatorMinRewardPercent", [epoch_number]}
    ]
  end

  # args = [staking_epoch, validator_staked, total_staked, pool_reward \\ 10_00000]
  def validator_reward_request(args) do
    [
      validator_share: {:block_reward, "validatorShare", args}
    ]
  end

  def perform_requests(requests, contracts, abi) do
    requests
    |> generate_requests(contracts)
    |> Reader.query_contracts(abi)
    |> parse_responses(requests)
  end

  def perform_grouped_requests(requests, keys, contracts, abi) do
    requests
    |> List.flatten()
    |> generate_requests(contracts)
    |> Reader.query_contracts(abi)
    |> parse_grouped_responses(keys, requests)
  end

  defp generate_requests(functions, contracts) do
    Enum.map(functions, fn
      {_, {contract, function, args}} ->
        %{
          contract_address: contracts[contract],
          function_name: function,
          args: args
        }

      {_, {contract, function, args, block_number}} ->
        %{
          contract_address: contracts[contract],
          function_name: function,
          args: args,
          block_number: block_number
        }
    end)
  end

  defp parse_responses(responses, requests) do
    requests
    |> Enum.zip(responses)
    |> Enum.into(%{}, fn {{key, _}, {:ok, response}} ->
      case response do
        [item] -> {key, item}
        items -> {key, items}
      end
    end)
  end

  defp parse_grouped_responses(responses, keys, grouped_requests) do
    {grouped_responses, _} = Enum.map_reduce(grouped_requests, responses, &Enum.split(&2, length(&1)))

    [keys, grouped_requests, grouped_responses]
    |> Enum.zip()
    |> Enum.into(%{}, fn {key, requests, responses} ->
      {key, parse_responses(responses, requests)}
    end)
  end
end
