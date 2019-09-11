defmodule Explorer.Staking.ContractState do
  @moduledoc """
  Fetches all information from POSDAO staking contracts.
  All contract calls are batched into four requests, according to their dependencies.
  Subscribes to new block notifications and refreshes when previously unseen block arrives.
  """

  use GenServer

  alias Explorer.Chain
  alias Explorer.Chain.Events.{Publisher, Subscriber}
  alias Explorer.SmartContract.Reader
  alias Explorer.Staking.ContractReader
  alias Explorer.Token.{BalanceReader, MetadataRetriever}

  @table_name __MODULE__
  @table_keys [
    :token_contract_address,
    :token,
    :min_candidate_stake,
    :min_delegator_stake,
    :epoch_number,
    :epoch_start_block,
    :epoch_end_block,
    :staking_allowed,
    :staking_contract,
    :validator_set_contract,
    :block_reward_contract
  ]

  defstruct [
    :seen_block,
    :contracts,
    :abi
  ]

  @spec get(atom(), value) :: value when value: any()
  def get(key, default \\ nil) when key in @table_keys do
    with info when info != :undefined <- :ets.info(@table_name),
         [{_, value}] <- :ets.lookup(@table_name, key) do
      value
    else
      _ -> default
    end
  end

  def start_link([]) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init([]) do
    :ets.new(@table_name, [
      :set,
      :named_table,
      :public,
      read_concurrency: true,
      write_concurrency: true
    ])

    Subscriber.to(:blocks, :realtime)

    staking_abi = abi("StakingAuRa")
    validator_set_abi = abi("ValidatorSetAuRa")
    block_reward_abi = abi("BlockRewardAuRa")

    staking_contract_address = Application.get_env(:explorer, __MODULE__)[:staking_contract_address]

    %{"validatorSetContract" => {:ok, [validator_set_contract_address]}} =
      Reader.query_contract(staking_contract_address, staking_abi, %{"validatorSetContract" => []})

    %{"blockRewardContract" => {:ok, [block_reward_contract_address]}} =
      Reader.query_contract(validator_set_contract_address, validator_set_abi, %{"blockRewardContract" => []})

    state = %__MODULE__{
      seen_block: 0,
      contracts: %{
        staking: staking_contract_address,
        validator_set: validator_set_contract_address,
        block_reward: block_reward_contract_address
      },
      abi: staking_abi ++ validator_set_abi ++ block_reward_abi
    }

    :ets.insert(@table_name,
      staking_contract: %{abi: staking_abi, address: staking_contract_address},
      validator_set_contract: %{abi: validator_set_abi, address: validator_set_contract_address},
      block_reward_contract: %{abi: block_reward_abi, address: block_reward_contract_address}
    )

    {:ok, state, {:continue, []}}
  end

  def handle_continue(_, state) do
    fetch_state(state.contracts, state.abi, state.seen_block)
    {:noreply, state}
  end

  @doc "Handles new blocks and decides to fetch fresh chain info"
  def handle_info({:chain_event, :blocks, :realtime, blocks}, state) do
    latest_block = Enum.max_by(blocks, & &1.number)

    if latest_block.number > state.seen_block do
      fetch_state(state.contracts, state.abi, latest_block.number)
      {:noreply, %{state | seen_block: latest_block.number}}
    else
      {:noreply, state}
    end
  end

  defp fetch_state(contracts, abi, block_number) do
    previous_epoch = get(:epoch_number, 0)

    global_responses = ContractReader.perform_requests(ContractReader.global_requests(), contracts, abi)
    token = get_token(global_responses.token_contract_address)

    settings =
      global_responses
      |> Map.take([
        :token_contract_address,
        :min_candidate_stake,
        :min_delegator_stake,
        :epoch_number,
        :epoch_start_block,
        :epoch_end_block,
        :staking_allowed
      ])
      |> Map.to_list()
      |> Enum.concat(token: token)

    :ets.insert(@table_name, settings)

    pools = global_responses.active_pools ++ global_responses.inactive_pools
    is_validator = Enum.into(global_responses.validators, %{}, &{hash_to_string(&1), true})
    unremovable_validator = global_responses.unremovable_validator

    pool_staking_responses =
      pools
      |> Enum.map(&ContractReader.pool_staking_requests/1)
      |> ContractReader.perform_grouped_requests(pools, contracts, abi)

    pool_mining_responses =
      pools
      |> Enum.map(&ContractReader.pool_mining_requests(pool_staking_responses[&1].mining_address_hash))
      |> ContractReader.perform_grouped_requests(pools, contracts, abi)

    delegators =
      Enum.flat_map(pool_staking_responses, fn {pool_address, responses} ->
        [{pool_address, pool_address, true}] ++
          Enum.map(responses.active_delegators, &{pool_address, &1, true}) ++
          Enum.map(responses.inactive_delegators, &{pool_address, &1, false})
      end)

    delegator_rewards =
      Enum.into(pool_staking_responses, %{}, fn {pool_address, responses} ->
        {pool_address, Enum.into(Enum.zip(responses.stakers, responses.reward_percents), %{})}
      end)

    delegator_responses =
      delegators
      |> Enum.map(fn {pool_address, delegator_address, _} ->
        ContractReader.delegator_requests(pool_address, delegator_address)
      end)
      |> ContractReader.perform_grouped_requests(delegators, contracts, abi)

    staked_total = Enum.sum(for {_, pool} <- pool_staking_responses, pool.is_active, do: pool.staked_amount)
    [likelihood_values, total_likelihood] = global_responses.pools_likelihood

    likelihood =
      global_responses.pools_likely
      |> Enum.zip(likelihood_values)
      |> Enum.into(%{})

    pool_entries =
      Enum.map(pools, fn staking_address ->
        staking_response = pool_staking_responses[staking_address]
        mining_response = pool_mining_responses[staking_address]

        %{
          staking_address_hash: staking_address,
          delegators_count: length(staking_response.active_delegators),
          staked_ratio:
            if staking_response.is_active do
              ratio(staking_response.staked_amount, staked_total)
            end,
          likelihood: ratio(likelihood[staking_address] || 0, total_likelihood),
          block_reward_ratio: staking_response.block_reward / 10_000,
          is_deleted: false,
          is_validator: is_validator[staking_response.mining_address_hash] || false,
          is_unremovable: hash_to_string(staking_address) == unremovable_validator,
          ban_reason: binary_to_string(mining_response.ban_reason)
        }
        |> Map.merge(
          Map.take(staking_response, [
            :mining_address_hash,
            :is_active,
            :staked_amount,
            :self_staked_amount
          ])
        )
        |> Map.merge(
          Map.take(mining_response, [
            :was_validator_count,
            :is_banned,
            :are_delegators_banned,
            :banned_until,
            :banned_delegators_until,
            :was_banned_count
          ])
        )
      end)

    delegator_entries =
      Enum.map(delegator_responses, fn {{pool_address, delegator_address, is_active}, response} ->
        staking_response = pool_staking_responses[pool_address]

        reward_ratio =
          if is_validator[staking_response.mining_address_hash] do
            reward_ratio = delegator_rewards[pool_address][delegator_address]

            if reward_ratio do
              reward_ratio / 10_000
            end
          else
            ratio(
              response.stake_amount - response.ordered_withdraw,
              staking_response.staked_amount - staking_response.self_staked_amount
            ) * min(0.7, 1 - staking_response.block_reward / 1_000_000)
          end

        Map.merge(response, %{
          delegator_address_hash: delegator_address,
          pool_address_hash: pool_address,
          is_active: is_active,
          reward_ratio: reward_ratio
        })
      end)

    {:ok, _} =
      Chain.import(%{
        staking_pools: %{params: pool_entries},
        staking_pools_delegators: %{params: delegator_entries},
        timeout: :infinity
      })

    if token && previous_epoch != global_responses.epoch_number do
      update_tokens(token.contract_address_hash, contracts, abi, global_responses.epoch_start_block - 1, block_number)
    end

    Publisher.broadcast(:staking_update)
  end

  defp update_tokens(token_contract_address_hash, contracts, abi, last_epoch_block_number, block_number) do
    now = DateTime.utc_now()

    token_params =
      token_contract_address_hash
      |> MetadataRetriever.get_functions_of()
      |> Map.merge(%{
        contract_address_hash: token_contract_address_hash,
        type: "ERC-20"
      })

    addresses =
      block_number
      |> ContractReader.pools_snapshot_requests()
      |> ContractReader.perform_requests(contracts, abi)
      |> Map.fetch!(:staking_addresses)
      |> Enum.flat_map(&ContractReader.stakers_snapshot_requests(&1, last_epoch_block_number))
      |> ContractReader.perform_requests(contracts, abi)
      |> Map.values()
      |> List.flatten()
      |> Enum.uniq()

    balance_params =
      addresses
      |> Enum.map(
        &%{
          token_contract_address_hash: token_contract_address_hash,
          address_hash: &1,
          block_number: block_number
        }
      )
      |> BalanceReader.get_balances_of()
      |> Enum.zip(addresses)
      |> Enum.map(fn {{:ok, balance}, address} ->
        %{
          address_hash: address,
          token_contract_address_hash: token_contract_address_hash,
          block_number: block_number,
          value: balance,
          value_fetched_at: now
        }
      end)

    {:ok, _} =
      Chain.import(%{
        addresses: %{params: Enum.map(addresses, &%{hash: &1}), on_conflict: :nothing},
        address_current_token_balances: %{params: balance_params},
        tokens: %{params: [token_params]}
      })
  end

  defp get_token(address) do
    with {:ok, address_hash} <- Chain.string_to_address_hash(address),
         {:ok, token} <- Chain.token_from_address_hash(address_hash) do
      token
    else
      _ -> nil
    end
  end

  defp ratio(_numerator, 0), do: 0
  defp ratio(numerator, denominator), do: numerator / denominator * 100

  defp hash_to_string(hash), do: "0x" <> Base.encode16(hash, case: :lower)

  # sobelow_skip ["Traversal"]
  defp abi(file_name) do
    :explorer
    |> Application.app_dir("priv/contracts_abi/posdao/#{file_name}.json")
    |> File.read!()
    |> Jason.decode!()
  end

  defp binary_to_string(binary) do
    binary
    |> :binary.bin_to_list()
    |> Enum.filter(fn x -> x != 0 end)
    |> List.to_string()
  end
end
