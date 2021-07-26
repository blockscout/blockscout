defmodule Explorer.Staking.StakeSnapshotting do
  @moduledoc """
  Makes snapshots of staked amounts.
  """

  import Ecto.Query, only: [from: 2]

  require Logger

  alias Explorer.Chain
  alias Explorer.Chain.Events.Publisher
  alias Explorer.Chain.{StakingPool, StakingPoolsDelegator}
  alias Explorer.Staking.ContractReader

  def do_snapshotting(
        %{contracts: contracts, abi: abi, ets_table_name: ets_table_name},
        epoch_number,
        cached_pool_staking_responses,
        pools_mining_addresses,
        mining_to_staking_address,
        mining_address_to_id,
        block_number
      ) do
    # get pool ids and staking addresses for the pending validators
    pool_ids =
      pools_mining_addresses
      |> Enum.map(&mining_address_to_id[&1])

    pool_staking_addresses =
      pools_mining_addresses
      |> Enum.map(&mining_to_staking_address[&1])

    id_to_mining_address =
      pool_ids
      |> Enum.zip(pools_mining_addresses)
      |> Map.new()

    id_to_staking_address =
      pool_ids
      |> Enum.zip(pool_staking_addresses)
      |> Map.new()

    # get snapshotted amounts and active delegator list for the pool for each
    # pending validator by their pool id.
    # use `cached_pool_staking_responses` when possible
    pool_staking_responses =
      pool_ids
      |> Enum.map(fn pool_id ->
        case Map.fetch(cached_pool_staking_responses, pool_id) do
          {:ok, resp} ->
            snapshotted_pool_amounts_requests(pool_id, resp.staking_address_hash, block_number)

          :error ->
            pool_staking_address = id_to_staking_address[pool_id]

            ContractReader.active_delegators_request(pool_id, block_number) ++
              snapshotted_pool_amounts_requests(pool_id, pool_staking_address, block_number)
        end
      end)
      |> ContractReader.perform_grouped_requests(pool_ids, contracts, abi)
      |> Map.new(fn {pool_id, resp} ->
        {pool_id,
         case Map.fetch(cached_pool_staking_responses, pool_id) do
           {:ok, cached_resp} ->
             Map.merge(cached_resp, resp)

           :error ->
             pool_staking_address = id_to_staking_address[pool_id]
             Map.merge(%{staking_address_hash: pool_staking_address}, resp)
         end}
      end)

    # get a flat list of all stakers of each validator
    # in the form of {pool_id, pool_staking_address, staker_address}
    stakers =
      Enum.flat_map(pool_staking_responses, fn {pool_id, resp} ->
        [{pool_id, resp.staking_address_hash, resp.staking_address_hash}] ++
          Enum.map(resp.active_delegators, &{pool_id, resp.staking_address_hash, &1})
      end)

    # read info about each staker from the contracts
    staker_responses = get_staker_responses(stakers, block_number, contracts, abi)

    # call `BlockReward.validatorShare` function for each pool
    # to get validator's reward share of the pool (needed for the `Delegators` list in UI)
    validator_reward_responses =
      get_validator_reward_responses(pool_staking_responses, epoch_number, block_number, contracts, abi)

    # call `BlockReward.delegatorShare` function for each delegator
    # to get their reward share of the pool (needed for the `Delegators` list in UI)
    delegator_reward_responses =
      staker_responses
      |> get_delegator_responses()
      |> get_delegator_reward_responses(pool_staking_responses, epoch_number, block_number, contracts, abi)

    # form entries for updating the `staking_pools` table in DB
    pool_entries =
      Enum.map(pool_ids, fn pool_id ->
        staking_resp = pool_staking_responses[pool_id]
        validator_reward_resp = validator_reward_responses[pool_id]
        pool_staking_address = id_to_staking_address[pool_id]

        %{
          banned_until: 0,
          is_active: false,
          is_banned: false,
          is_unremovable: false,
          is_validator: false,
          staking_address_hash: pool_staking_address,
          delegators_count: 0,
          mining_address_hash: address_bytes_to_string(id_to_mining_address[pool_id]),
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
      Enum.map(staker_responses, fn {{_pool_id, pool_staking_address, staker_address} = key, resp} ->
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

  defp get_delegator_responses(staker_responses) do
    Enum.reduce(staker_responses, %{}, fn {{_pool_id, pool_staking_address, staker_address} = key, value}, acc ->
      if pool_staking_address != staker_address do
        Map.put(acc, key, value)
      else
        acc
      end
    end)
  end

  defp get_delegator_reward_responses(
         delegator_responses,
         pool_staking_responses,
         epoch_number,
         block_number,
         contracts,
         abi
       ) do
    delegator_keys = Enum.map(delegator_responses, fn {key, _} -> key end)

    delegator_requests =
      delegator_responses
      |> Enum.map(fn {{pool_id, _pool_staking_address, _staker_address}, resp} ->
        staking_resp = pool_staking_responses[pool_id]

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

    chunk_size = 100
    chunks = 0..trunc(ceil(Enum.count(delegator_keys) / chunk_size) - 1)

    Enum.reduce(chunks, %{}, fn i, acc ->
      delegator_keys_slice = Enum.slice(delegator_keys, i * chunk_size, chunk_size)

      responses =
        delegator_requests
        |> Enum.slice(i * chunk_size, chunk_size)
        |> ContractReader.perform_grouped_requests(delegator_keys_slice, contracts, abi)

      Map.merge(acc, responses)
    end)
  end

  defp get_staker_responses(stakers, block_number, contracts, abi) do
    # we split batch requests by chunks
    chunk_size = 100
    chunks = 0..trunc(ceil(Enum.count(stakers) / chunk_size) - 1)

    Enum.reduce(chunks, %{}, fn i, acc ->
      stakers_slice = Enum.slice(stakers, i * chunk_size, chunk_size)

      responses =
        stakers_slice
        |> Enum.map(fn {pool_id, pool_staking_address, staker_address} ->
          snapshotted_staker_amount_request(pool_id, pool_staking_address, staker_address, block_number)
        end)
        |> ContractReader.perform_grouped_requests(stakers_slice, contracts, abi)

      Map.merge(acc, responses)
    end)
  end

  defp get_validator_reward_responses(pool_staking_responses, epoch_number, block_number, contracts, abi) do
    # to keep sort order when using `perform_grouped_requests` (see below)
    pool_ids = Enum.map(pool_staking_responses, fn {pool_id, _} -> pool_id end)

    pool_staking_responses
    |> Enum.map(fn {_pool_id, resp} ->
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
    |> ContractReader.perform_grouped_requests(pool_ids, contracts, abi)
  end

  defp snapshotted_pool_amounts_requests(pool_id, pool_staking_address, block_number) do
    [
      # 2a8f6ecd = keccak256(stakeAmountTotal(uint256))
      snapshotted_total_staked_amount: {:staking, "2a8f6ecd", [pool_id], block_number},
      snapshotted_self_staked_amount:
        snapshotted_staker_amount_request(
          pool_id,
          pool_staking_address,
          pool_staking_address,
          block_number
        )[:snapshotted_stake_amount]
    ]
  end

  defp snapshotted_staker_amount_request(pool_id, pool_staking_address, staker_address, block_number) do
    delegator_or_zero =
      if staker_address == pool_staking_address do
        "0x0000000000000000000000000000000000000000"
      else
        staker_address
      end

    [
      # 3fb1a1e4 = keccak256(stakeAmount(uint256,address))
      snapshotted_stake_amount: {:staking, "3fb1a1e4", [pool_id, delegator_or_zero], block_number}
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
