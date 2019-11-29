defmodule Explorer.Staking.StakeSnapshotting do
  @moduledoc """
  Makes snapshots of staked amounts.
  """

  import Ecto.Query, only: [from: 2]

  require Logger

  alias Explorer.Chain
  alias Explorer.Chain.{StakingPool, StakingPoolsDelegator}
  alias Explorer.Staking.ContractReader

  def do_snapshotting(
    %{contracts: contracts, abi: abi, ets_table_name: ets_table_name},
    epoch_number,
    cached_pool_staking_responses,
    cached_pool_mining_responses,
    cached_staker_responses,
    pending_validators_mining_addresses,
    mining_to_staking_address,
    block_number
  ) do
    :ets.insert(ets_table_name, is_snapshotted: false)

    # get staking addresses for the pending validators
    pool_staking_addresses =
      pending_validators_mining_addresses
      |> Enum.map(&mining_to_staking_address[&1])

    # get snapshotted amounts and other pool info for each
    # pending validator by their staking address.
    # use `cached_pool_staking_responses` when possible
    pool_staking_responses =
      pool_staking_addresses
      |> Enum.map(fn staking_address_hash -> 
        case Map.fetch(cached_pool_staking_responses, staking_address_hash) do
          {:ok, resp} ->
            Map.merge(resp, ContractReader.perform_requests(snapshotted_pool_amounts_requests(staking_address_hash, block_number), contracts, abi))
          :error ->
            ContractReader.perform_requests(
              ContractReader.pool_staking_requests(staking_address_hash) ++ snapshotted_pool_amounts_requests(staking_address_hash, block_number),
              contracts,
              abi
            )
        end
      end)
      |> Enum.zip(pool_staking_addresses)
      |> Map.new(fn {key, val} -> {val, key} end)

    # read pool info from the contracts by its mining address.
    # use `cached_pool_mining_responses` when possible
    pool_mining_responses =
      pool_staking_addresses
      |> Enum.map(fn staking_address_hash -> 
        case Map.fetch(cached_pool_mining_responses, staking_address_hash) do
          {:ok, resp} ->
            resp
          :error ->
            pool_staking_responses[staking_address_hash].mining_address_hash
            |> ContractReader.pool_mining_requests()
            |> ContractReader.perform_requests(contracts, abi)
        end
      end)
      |> Enum.zip(pool_staking_addresses)
      |> Map.new(fn {key, val} -> {val, key} end)

    # get a flat list of all stakers of each validator
    # in the form of {pool_staking_address, staker_address}
    stakers =
      Enum.flat_map(pool_staking_responses, fn {pool_staking_address, resp} ->
        [{pool_staking_address, pool_staking_address}] ++
          Enum.map(resp.active_delegators, &{pool_staking_address, &1})
      end)

    # read info of each staker from the contracts.
    # use `cached_staker_responses` when possible
    staker_responses =
      stakers
      |> Enum.map(fn {pool_staking_address, staker_address} = key ->
        case Map.fetch(cached_staker_responses, key) do
          {:ok, resp} ->
            Map.merge(
              resp,
              ContractReader.perform_requests(
                snapshotted_staker_amount_request(pool_staking_address, staker_address, block_number),
                contracts,
                abi
              )
            )
          :error ->
            ContractReader.perform_requests(
              ContractReader.staker_requests(pool_staking_address, staker_address) ++ snapshotted_staker_amount_request(pool_staking_address, staker_address, block_number),
              contracts,
              abi
            )
        end
      end)
      |> Enum.zip(stakers)
      |> Map.new(fn {key, val} -> {val, key} end)

    # to keep sort order when using `perform_grouped_requests` (see below)
    pool_staking_keys = Enum.map(pool_staking_responses, fn {key, _} -> key end)

    # call `BlockReward.validatorShare` function for each pool
    # to get validator's reward share of the pool (needed for the `Delegators` list in UI)
    validator_reward_responses =
      pool_staking_responses
      |> Enum.map(fn {_pool_staking_address, resp} ->
        ContractReader.validator_reward_requests([
          epoch_number,
          resp.snapshotted_self_staked_amount,
          resp.snapshotted_total_staked_amount,
          1000_000
        ])
      end)
      |> ContractReader.perform_grouped_requests(pool_staking_keys, contracts, abi)

    # to keep sort order when using `perform_grouped_requests` (see below)
    delegator_keys = Enum.map(staker_responses, fn {key, _} -> key end)

    # call `BlockReward.delegatorShare` function for each delegator
    # to get their reward share of the pool (needed for the `Delegators` list in UI)
    delegator_reward_responses =
      staker_responses
      |> Enum.map(fn {{pool_staking_address, _staker_address}, resp} ->
        staking_resp = pool_staking_responses[pool_staking_address]

        ContractReader.delegator_reward_requests([
          epoch_number,
          resp.snapshotted_stake_amount,
          staking_resp.snapshotted_self_staked_amount,
          staking_resp.snapshotted_total_staked_amount,
          1000_000
        ])
      end)
      |> ContractReader.perform_grouped_requests(delegator_keys, contracts, abi)

    # form entries for updating the `staking_pools` table in DB
    pool_entries =
      Enum.map(pool_staking_addresses, fn pool_staking_address ->
        staking_resp = pool_staking_responses[pool_staking_address]
        mining_resp = pool_mining_responses[pool_staking_address]
        validator_reward_resp = validator_reward_responses[pool_staking_address]

        %{
          staking_address_hash: pool_staking_address,
          delegators_count: 0,
          snapshotted_validator_reward_ratio: Float.floor(validator_reward_resp.validator_share / 10_000, 2)
        }
        |> Map.merge(
          Map.take(staking_resp, [
            :mining_address_hash,
            :self_staked_amount,
            :snapshotted_self_staked_amount,
            :snapshotted_total_staked_amount,
            :total_staked_amount
          ])
        )
        |> Map.merge(
          Map.take(mining_resp, [
            :banned_until,
            :was_banned_count,
            :was_validator_count
          ])
        )
      end)

    # form entries for updating the `staking_pools_delegators` table in DB
    delegator_entries =
      Enum.map(staker_responses, fn {{pool_staking_address, staker_address}, resp} ->
        delegator_reward_resp = delegator_reward_responses[{pool_staking_address, staker_address}]

        Map.merge(resp, %{
          address_hash: staker_address,
          staking_address_hash: pool_staking_address,
          snapshotted_reward_ratio: Float.floor(delegator_reward_resp.delegator_share / 10_000, 2)
        })
      end)

    # perform SQL queries
    case Chain.import(%{
      staking_pools: %{params: pool_entries, on_conflict: staking_pools_update(), clear_snapshotted_values: true},
      staking_pools_delegators: %{params: delegator_entries, on_conflict: staking_pools_delegators_update(), clear_snapshotted_values: true},
      timeout: :infinity
    }) do
      {:ok, _} -> :ets.insert(ets_table_name, is_snapshotted: true)
      _ -> Logger.error("Cannot finish snapshotting started at block #{block_number}")
    end
  end

  defp snapshotted_pool_amounts_requests(pool_staking_address, block_number) do
    [
      snapshotted_total_staked_amount: {:staking, "stakeAmountTotal", [pool_staking_address], block_number},
      snapshotted_self_staked_amount: snapshotted_staker_amount_request(pool_staking_address, pool_staking_address, block_number)[:snapshotted_stake_amount]
    ]
  end

  defp snapshotted_staker_amount_request(pool_staking_address, staker_address, block_number) do
    [
      snapshotted_stake_amount: {:staking, "stakeAmount", [pool_staking_address, staker_address], block_number}
    ]
  end

  defp staking_pools_update do
    from(
      pool in StakingPool,
      update: [
        set: [
          snapshotted_self_staked_amount: fragment("EXCLUDED.snapshotted_self_staked_amount"),
          snapshotted_total_staked_amount: fragment("EXCLUDED.snapshotted_total_staked_amount"),
          snapshotted_validator_reward_ratio: fragment("EXCLUDED.snapshotted_validator_reward_ratio"),
          updated_at: fragment("GREATEST(?, EXCLUDED.updated_at)", pool.updated_at)
        ]
      ]
    )
  end

  defp staking_pools_delegators_update do
    from(
      delegator in StakingPoolsDelegator,
      update: [
        set: [
          snapshotted_reward_ratio: fragment("EXCLUDED.snapshotted_reward_ratio"),
          snapshotted_stake_amount: fragment("EXCLUDED.snapshotted_stake_amount"),
          updated_at: fragment("GREATEST(?, EXCLUDED.updated_at)", delegator.updated_at)
        ]
      ]
    )
  end
end
