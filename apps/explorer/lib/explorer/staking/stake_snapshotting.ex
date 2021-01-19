defmodule Explorer.Staking.StakeSnapshotting do
  @moduledoc """
  Makes snapshots of staked amounts.
  """

  import Ecto.Query, only: [from: 2]

  require Logger

  alias Explorer.Chain
  alias Explorer.Chain.{StakingPool, StakingPoolsDelegator}
  alias Explorer.Chain.Events.Publisher
  alias Explorer.Staking.ContractReader

  def do_snapshotting(
        %{contracts: contracts, abi: abi, ets_table_name: ets_table_name},
        epoch_number,
        cached_pool_staking_responses,
        pools_mining_addresses,
        mining_to_staking_address,
        block_number
      ) do
    # get staking addresses for the pending validators
    pool_staking_addresses =
      pools_mining_addresses
      |> Enum.map(&mining_to_staking_address[&1])

    staking_to_mining_address =
      pool_staking_addresses
      |> Enum.zip(pools_mining_addresses)
      |> Map.new()

    # get snapshotted amounts and active delegator list for the pool for each
    # pending validator by their staking address.
    # use `cached_pool_staking_responses` when possible
    pool_staking_responses =
      pool_staking_addresses
      |> Enum.map(fn staking_address_hash ->
        case Map.fetch(cached_pool_staking_responses, staking_address_hash) do
          {:ok, resp} ->
            Map.merge(
              resp,
              ContractReader.perform_requests(
                snapshotted_pool_amounts_requests(staking_address_hash, block_number),
                contracts,
                abi
              )
            )

          :error ->
            ContractReader.perform_requests(
              ContractReader.active_delegators_request(staking_address_hash, block_number) ++
                snapshotted_pool_amounts_requests(staking_address_hash, block_number),
              contracts,
              abi
            )
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

    # read info about each staker from the contracts
    staker_responses =
      stakers
      |> Enum.map(fn {pool_staking_address, staker_address} ->
        ContractReader.perform_requests(
          snapshotted_staker_amount_request(pool_staking_address, staker_address, block_number),
          contracts,
          abi
        )
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
        ContractReader.validator_reward_request(
          [
            epoch_number,
            resp.snapshotted_self_staked_amount,
            resp.snapshotted_total_staked_amount,
            1000_000
          ],
          block_number
        )
      end)
      |> ContractReader.perform_grouped_requests(pool_staking_keys, contracts, abi)

    # call `BlockReward.delegatorShare` function for each delegator
    # to get their reward share of the pool (needed for the `Delegators` list in UI)
    delegator_responses =
      Enum.reduce(staker_responses, %{}, fn {{pool_staking_address, staker_address} = key, value}, acc ->
        if pool_staking_address != staker_address do
          Map.put(acc, key, value)
        else
          acc
        end
      end)

    delegator_keys = Enum.map(delegator_responses, fn {key, _} -> key end)

    delegator_reward_responses =
      delegator_responses
      |> Enum.map(fn {{pool_staking_address, _staker_address}, resp} ->
        staking_resp = pool_staking_responses[pool_staking_address]

        ContractReader.delegator_reward_request(
          [
            epoch_number,
            resp.snapshotted_stake_amount,
            staking_resp.snapshotted_self_staked_amount,
            staking_resp.snapshotted_total_staked_amount,
            1000_000
          ],
          block_number
        )
      end)
      |> ContractReader.perform_grouped_requests(delegator_keys, contracts, abi)

    # form entries for updating the `staking_pools` table in DB
    pool_entries =
      Enum.map(pool_staking_addresses, fn pool_staking_address ->
        staking_resp = pool_staking_responses[pool_staking_address]
        validator_reward_resp = validator_reward_responses[pool_staking_address]

        %{
          banned_until: 0,
          is_active: false,
          is_banned: false,
          is_unremovable: false,
          is_validator: false,
          staking_address_hash: pool_staking_address,
          delegators_count: 0,
          mining_address_hash: address_bytes_to_string(staking_to_mining_address[pool_staking_address]),
          self_staked_amount: 0,
          snapshotted_self_staked_amount: staking_resp.snapshotted_self_staked_amount,
          snapshotted_total_staked_amount: staking_resp.snapshotted_total_staked_amount,
          snapshotted_validator_reward_ratio: Float.floor(validator_reward_resp.validator_share / 10_000, 2),
          total_staked_amount: 0,
          was_banned_count: 0,
          was_validator_count: 0
        }
      end)

    # form entries for updating the `staking_pools_delegators` table in DB
    delegator_entries =
      Enum.map(staker_responses, fn {{pool_staking_address, staker_address} = key, resp} ->
        delegator_share =
          if Map.has_key?(delegator_reward_responses, key) do
            delegator_reward_responses[key].delegator_share
          else
            0
          end

        %{
          address_hash: staker_address,
          is_active: false,
          max_ordered_withdraw_allowed: 0,
          max_withdraw_allowed: 0,
          ordered_withdraw: 0,
          ordered_withdraw_epoch: 0,
          snapshotted_reward_ratio: Float.floor(delegator_share / 10_000, 2),
          snapshotted_stake_amount: resp.snapshotted_stake_amount,
          stake_amount: 0,
          staking_address_hash: pool_staking_address
        }
      end)

    # perform SQL queries
    case Chain.import(%{
           staking_pools: %{params: pool_entries, on_conflict: staking_pools_update(), clear_snapshotted_values: true},
           staking_pools_delegators: %{
             params: delegator_entries,
             on_conflict: staking_pools_delegators_update(),
             clear_snapshotted_values: true
           },
           timeout: :infinity
         }) do
      {:ok, _} -> :ets.insert(ets_table_name, snapshotted_epoch_number: epoch_number)
      _ -> Logger.error("Cannot successfully finish snapshotting for the epoch #{epoch_number - 1}")
    end

    :ets.insert(ets_table_name, is_snapshotting: false)

    Publisher.broadcast(:stake_snapshotting_finished)
  end

  defp address_bytes_to_string(hash), do: "0x" <> Base.encode16(hash, case: :lower)

  defp snapshotted_pool_amounts_requests(pool_staking_address, block_number) do
    [
      # 5267e1d6 = keccak256(stakeAmountTotal(address))
      snapshotted_total_staked_amount: {:staking, "5267e1d6", [pool_staking_address], block_number},
      snapshotted_self_staked_amount:
        snapshotted_staker_amount_request(pool_staking_address, pool_staking_address, block_number)[
          :snapshotted_stake_amount
        ]
    ]
  end

  defp snapshotted_staker_amount_request(pool_staking_address, staker_address, block_number) do
    [
      # a697ecff = keccak256(stakeAmount(address,address))
      snapshotted_stake_amount: {:staking, "a697ecff", [pool_staking_address, staker_address], block_number}
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
