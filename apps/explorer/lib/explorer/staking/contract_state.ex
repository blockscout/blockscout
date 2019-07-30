defmodule Explorer.Staking.ContractState do
  @moduledoc """
  Fetches all information from POSDAO staking contracts.
  All contract calls are batched into four requests, according to their dependencies.
  Subscribes to new block notifications and refreshes when previously unseen block arrives.
  """

  use GenServer

  alias Explorer.Chain
  alias Explorer.Chain.Events.Subscriber
  alias Explorer.SmartContract.Reader
  alias Explorer.Staking.ContractReader

  @table_name __MODULE__
  @table_keys [
    :token_contract_address,
    :token,
    :min_candidate_stake,
    :min_delegator_stake,
    :epoch_number,
    :epoch_end_block
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

    {:ok, state, {:continue, []}}
  end

  def handle_continue(_, state) do
    fetch_state(state.contracts, state.abi)
    {:noreply, state}
  end

  @doc "Handles new blocks and decides to fetch fresh chain info"
  def handle_info({:chain_event, :blocks, :realtime, blocks}, state) do
    latest_block = Enum.max_by(blocks, & &1.number)

    if latest_block.number > state.seen_block do
      fetch_state(state.contracts, state.abi)
      {:noreply, %{state | seen_block: latest_block.number}}
    else
      {:noreply, state}
    end
  end

  defp fetch_state(contracts, abi) do
    global_responses = ContractReader.perform_requests(ContractReader.global_requests(), contracts, abi)

    settings =
      global_responses
      |> Map.take([
        :token_contract_address,
        :min_candidate_stake,
        :min_delegator_stake,
        :epoch_number,
        :epoch_end_block
      ])
      |> Map.to_list()
      |> Enum.concat(token: get_token(global_responses.token_contract_address))

    :ets.insert(@table_name, settings)

    pools = global_responses.active_pools ++ global_responses.inactive_pools

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
        Enum.map(responses.active_delegators, &{pool_address, &1, true}) ++
          Enum.map(responses.inactive_delegators, &{pool_address, &1, false})
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
          staked_ratio: ratio(staking_response.staked_amount, staked_total),
          likelihood: ratio(likelihood[staking_address] || 0, total_likelihood),
          block_reward_ratio: staking_response.block_reward / 10_000,
          is_deleted: false
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
            :is_validator,
            :was_validator_count,
            :is_banned,
            :banned_until,
            :was_banned_count
          ])
        )
      end)

    delegator_entries =
      Enum.map(delegator_responses, fn {{pool_address, delegator_address, is_active}, response} ->
        Map.merge(response, %{
          delegator_address_hash: delegator_address,
          pool_address_hash: pool_address,
          is_active: is_active
        })
      end)

    {:ok, _} =
      Chain.import(%{
        staking_pools: %{params: pool_entries},
        staking_pools_delegators: %{params: delegator_entries},
        timeout: :infinity
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

  # sobelow_skip ["Traversal"]
  defp abi(file_name) do
    :explorer
    |> Application.app_dir("priv/contracts_abi/posdao/#{file_name}.json")
    |> File.read!()
    |> Jason.decode!()
  end
end
