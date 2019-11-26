defmodule Explorer.Staking.StakeSnapshotting do
  @moduledoc """
  Need to store stakeAmount from previous block in the beginning of new epoch.
  for validators

  """

  import Ecto.Query, only: [from: 2]

  require Logger

  alias Explorer.Chain
  alias Explorer.Chain.{StakingPool, StakingPoolsDelegator}
  alias Explorer.SmartContract.Reader
  alias Explorer.Staking.ContractReader

  def do_snapshotting(
    %{contracts: contracts, abi: abi, epoch_number: epoch_number, ets_table_name: ets_table_name},
    cached_pool_staking_responses,
    cached_staker_responses,
    block_number
  ) do
    :ets.insert(ets_table_name, is_snapshotted: false)

    # get the list of pending validators
    %{
      "getPendingValidators" => {:ok, [pending_validators]},
      "validatorsToBeFinalized" => {:ok, [to_be_finalized_validators]}
    } =
      Reader.query_contract(contracts.validator_set, abi, %{
        "getPendingValidators" => [],
        "validatorsToBeFinalized" => []
      })

    pool_mining_addresses = Enum.uniq(pending_validators ++ to_be_finalized_validators)

    # get staking addresses for the pending validators
    pool_staking_addresses =
      pool_mining_addresses
      |> Enum.map(&staking_by_mining_requests/1)
      |> ContractReader.perform_grouped_requests(pool_mining_addresses, contracts, abi)
      |> Enum.flat_map(fn {_, value} -> value end)
      |> Enum.map(fn {_key, staking_address_hash} -> decode_data(staking_address_hash) end)

    # get snapshotted amounts and other pool info for each pending validator.
    # use `cached_pool_staking_responses` when possible
    pool_staking_responses =
      pool_staking_addresses
      |> Enum.map(fn address_hash -> 
        case Map.fetch(cached_pool_staking_responses, address_hash) do
          {:ok, resp} ->
            Map.merge(resp, ContractReader.perform_requests(snapshotted_amounts_requests(address_hash, block_number), contracts, abi))
          :error ->
            ContractReader.perform_requests(pool_staking_requests(address_hash, block_number), contracts, abi)
        end
      end)
      |> Enum.zip(pool_staking_addresses)
      |> Map.new(fn {key, val} -> {val, key} end)

    pool_mining_responses =
      pool_staking_addresses
      |> Enum.map(&ContractReader.pool_mining_requests(pool_staking_responses[&1].mining_address_hash))
      |> ContractReader.perform_grouped_requests(pool_staking_addresses, contracts, abi)

    # form a flat list of all stakers in the form {pool_staking_address, staker_address}
    stakers =
      Enum.flat_map(pool_staking_responses, fn {pool_staking_address, resp} ->
        [{pool_staking_address, pool_staking_address}] ++
          Enum.map(resp.active_delegators, &{pool_staking_address, &1}) ++
          Enum.map(resp.inactive_delegators, &{pool_staking_address, &1})
      end)

    # get amounts for each of the stakers
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
              staker_requests(pool_staking_address, staker_address, block_number),
              contracts,
              abi
            )
        end
      end)
      |> Enum.zip(stakers)
      |> Map.new(fn {key, val} -> {val, key} end)

    pool_staking_keys = Enum.map(pool_staking_responses, fn {key, _} -> key end)

    pool_reward_responses =
      pool_staking_responses
      |> Enum.map(fn {_address, resp} ->
        ContractReader.validator_reward_requests([
          epoch_number,
          resp.snapshotted_self_staked_amount,
          resp.snapshotted_total_staked_amount,
          1000_000
        ])
      end)
      |> ContractReader.perform_grouped_requests(pool_staking_keys, contracts, abi)

    delegator_keys = Enum.map(staker_responses, fn {key, _} -> key end)

    delegator_reward_responses =
      staker_responses
      |> Enum.map(fn {{pool_address, _delegator_address}, response} ->
        staking_response = pool_staking_responses[pool_address]

        ContractReader.delegator_reward_requests([
          epoch_number,
          response.snapshotted_stake_amount,
          staking_response.snapshotted_self_staked_amount,
          staking_response.snapshotted_total_staked_amount,
          1000_000
        ])
      end)
      |> ContractReader.perform_grouped_requests(delegator_keys, contracts, abi)

    pool_entries =
      Enum.map(pool_staking_addresses, fn staking_address ->
        staking_response = pool_staking_responses[staking_address]
        mining_response = pool_mining_responses[staking_address]
        pool_reward_response = pool_reward_responses[staking_address]

        %{
          staking_address_hash: staking_address,
          delegators_count: length(staking_response.active_delegators),
          snapshotted_validator_reward_ratio: Float.floor(pool_reward_response.validator_share / 10_000, 2)
        }
        |> Map.merge(
          Map.take(staking_response, [
            :mining_address_hash,
            :self_staked_amount,
            :snapshotted_self_staked_amount,
            :snapshotted_total_staked_amount,
            :total_staked_amount
          ])
        )
        |> Map.merge(
          Map.take(mining_response, [
            :banned_until,
            :was_banned_count,
            :was_validator_count
          ])
        )
      end)

    delegator_entries =
      Enum.map(staker_responses, fn {{pool_staking_address, staker_address}, response} ->
        delegator_reward_response = delegator_reward_responses[{pool_staking_address, staker_address}]

        # %{
        #   address_hash: staker_address,
        #   staking_address_hash: pool_staking_address,
        #   snapshotted_stake_amount: response.snapshotted_stake_amount,
        #   snapshotted_reward_ratio: Float.floor(delegator_reward_response.delegator_share / 10_000, 2)
        # }
        Map.merge(response, %{
          address_hash: staker_address,
          staking_address_hash: pool_staking_address,
          snapshotted_reward_ratio: Float.floor(delegator_reward_response.delegator_share / 10_000, 2)
        })
      end)

    case Chain.import(%{
      staking_pools: %{params: pool_entries, on_conflict: staking_pool_on_conflict()},
      staking_pools_delegators: %{params: delegator_entries, on_conflict: staking_pools_delegators_update()},
      timeout: :infinity
    }) do
      {:ok, _} -> :ets.insert(ets_table_name, is_snapshotted: true)
      _ -> Logger.error("Cannot finish snapshotting started at block #{block_number}")
    end
  end

  def staking_by_mining_requests(mining_address) do
    [
      staking_address: {:validator_set, "stakingByMiningAddress", [mining_address]}
    ]
  end

  defp pool_staking_requests(staking_address, block_number) do
    [
      total_staked_amount: {:staking, "stakeAmountTotal", [staking_address]},
      self_staked_amount: {:staking, "stakeAmount", [staking_address, staking_address]},
      mining_address_hash: {:validator_set, "miningByStakingAddress", [staking_address]},
      active_delegators: {:staking, "poolDelegators", [staking_address]},
      inactive_delegators: {:staking, "poolDelegatorsInactive", [staking_address]}
    ] ++ snapshotted_amounts_requests(staking_address, block_number)
  end

  defp snapshotted_amounts_requests(staking_address, block_number) do
    [
      snapshotted_total_staked_amount: {:staking, "stakeAmountTotal", [staking_address], block_number},
      snapshotted_self_staked_amount: {:staking, "stakeAmount", [staking_address, staking_address], block_number}
    ]
  end

  defp staker_requests(pool_staking_address, staker_address, block_number) do
    [
      max_ordered_withdraw_allowed: {:staking, "maxWithdrawOrderAllowed", [pool_staking_address, staker_address]},
      max_withdraw_allowed: {:staking, "maxWithdrawAllowed", [pool_staking_address, staker_address]},
      ordered_withdraw: {:staking, "orderedWithdrawAmount", [pool_staking_address, staker_address]},
      ordered_withdraw_epoch: {:staking, "orderWithdrawEpoch", [pool_staking_address, staker_address]},
      stake_amount: {:staking, "stakeAmount", [pool_staking_address, staker_address]}
    ] ++ snapshotted_staker_amount_request(pool_staking_address, staker_address, block_number)
  end

  defp snapshotted_staker_amount_request(pool_staking_address, staker_address, block_number) do
    [
      snapshotted_stake_amount: {:staking, "stakeAmount", [pool_staking_address, staker_address], block_number}
    ]
  end

  defp staking_pool_on_conflict do
    from(
      pool in StakingPool,
      update: [
        set: [
          mining_address_hash: fragment("EXCLUDED.mining_address_hash"),
          delegators_count: fragment("EXCLUDED.delegators_count"),
          snapshotted_validator_reward_ratio: fragment("EXCLUDED.snapshotted_validator_reward_ratio"),
          self_staked_amount: fragment("EXCLUDED.self_staked_amount"),
          total_staked_amount: fragment("EXCLUDED.total_staked_amount"),
          snapshotted_self_staked_amount: fragment("EXCLUDED.snapshotted_self_staked_amount"),
          snapshotted_total_staked_amount: fragment("EXCLUDED.snapshotted_total_staked_amount"),
          is_active: pool.is_active,
          is_banned: pool.is_banned,
          is_validator: pool.is_validator,
          is_unremovable: pool.is_unremovable,
          are_delegators_banned: pool.are_delegators_banned,
          likelihood: pool.likelihood,
          block_reward_ratio: pool.block_reward_ratio,
          stakes_ratio: pool.stakes_ratio,
          validator_reward_ratio: pool.validator_reward_ratio,
          ban_reason: pool.ban_reason,
          was_banned_count: pool.was_banned_count,
          was_validator_count: pool.was_validator_count,
          banned_until: pool.banned_until,
          is_deleted: pool.is_deleted,
          banned_delegators_until: pool.banned_delegators_until,
          inserted_at: fragment("LEAST(?, EXCLUDED.inserted_at)", pool.inserted_at),
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
          snapshotted_stake_amount: fragment("EXCLUDED.snapshotted_stake_amount"),
          snapshotted_reward_ratio: fragment("EXCLUDED.snapshotted_reward_ratio"),
          updated_at: fragment("GREATEST(?, EXCLUDED.updated_at)", delegator.updated_at)
        ]
      ]
    )
  end

  defp decode_data(address_hash_string) do
    {
      :ok,
      %Chain.Hash{
        byte_count: _,
        bytes: bytes
      }
    } = Chain.string_to_address_hash(address_hash_string)

    bytes
  end
end
