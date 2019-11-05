defmodule Explorer.Staking.StakeSnapshotting do
  @moduledoc """
  Need to store stakeAmount from previous block in the beginning of new epoch.
  for validators
  params:
  current block number

  """

  use GenServer

  alias Explorer.Chain
  alias Explorer.SmartContract.Reader
  alias Explorer.Staking.ContractReader

  defstruct [
    :block_number,
    :contracts,
    :abi
  ]

  def start_link(opts) do
    {block_number, _opts} = Keyword.pop(opts, :block_number)
    GenServer.start_link(__MODULE__, block_number, name: __MODULE__)
  end

  def init(block_number) do
    staking_abi = abi("StakingAuRa")
    validator_set_abi = abi("ValidatorSetAuRa")
    block_reward_abi = abi("BlockRewardAuRa")

    staking_contract_address = Application.get_env(:explorer, Explorer.Staking.ContractState)[:staking_contract_address]

    %{"validatorSetContract" => {:ok, [validator_set_contract_address]}} =
      Reader.query_contract(staking_contract_address, staking_abi, %{"validatorSetContract" => []})

    %{"blockRewardContract" => {:ok, [block_reward_contract_address]}} =
      Reader.query_contract(validator_set_contract_address, validator_set_abi, %{"blockRewardContract" => []})

    state = %__MODULE__{
      block_number: block_number,
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
    start_snapshoting(state)
    {:noreply, state}
  end

  defp start_snapshoting(%{contracts: contracts, abi: abi, block_number: block_number} = _state) do
    %{
      "getPendingValidators" => {:ok, [pending_validators_mining_addresses]},
      "validatorsToBeFinalized" => {:ok, [be_finalized_validators_mining_addresses]}
    } =
      Reader.query_contract(contracts.validator_set, abi, %{
        "getPendingValidators" => [],
        "validatorsToBeFinalized" => []
      })

    pool_mining_addresses = pending_validators_mining_addresses ++ be_finalized_validators_mining_addresses

    pool_staking_addresses =
      pool_mining_addresses
      |> Enum.map(&transform_requests/1)
      |> ContractReader.perform_grouped_requests(pool_mining_addresses, contracts, abi)
      |> Enum.flat_map(fn {_, value} -> value end)
      |> Enum.map(fn {_key, staking_address_hash} -> decode_data(staking_address_hash) end)

    pool_staking_responses =
      pool_staking_addresses
      |> Enum.map(fn address_hashe -> pool_staking_requests(address_hashe, block_number) end)
      |> ContractReader.perform_grouped_requests(pool_staking_addresses, contracts, abi)

    pool_mining_responses =
      pool_staking_addresses
      |> Enum.map(&ContractReader.pool_mining_requests(pool_staking_responses[&1].mining_address_hash))
      |> ContractReader.perform_grouped_requests(pool_staking_addresses, contracts, abi)

    delegators =
      Enum.flat_map(pool_staking_responses, fn {pool_address, responses} ->
        [{pool_address, pool_address, true}] ++
          Enum.map(responses.active_delegators, &{pool_address, &1, true}) ++
          Enum.map(responses.inactive_delegators, &{pool_address, &1, false})
      end)

    delegator_responses =
      delegators
      |> Enum.map(fn {pool_address, delegator_address, _} ->
        delegator_requests(pool_address, delegator_address, block_number)
      end)
      |> ContractReader.perform_grouped_requests(delegators, contracts, abi)

    pool_entries =
      Enum.map(pool_staking_addresses, fn staking_address ->
        staking_response = pool_staking_responses[staking_address]
        mining_response = pool_mining_responses[staking_address]

        %{
          staking_address_hash: staking_address,
          delegators_count: length(staking_response.active_delegators)
        }
        |> Map.merge(
          Map.take(staking_response, [
            :snapshotted_staked_amount,
            :snapshotted_self_staked_amount,
            :staked_amount,
            :self_staked_amount,
            :mining_address_hash
          ])
        )
        |> Map.merge(
          Map.take(mining_response, [
            :was_validator_count,
            :was_banned_count,
            :banned_until
          ])
        )
      end)

    delegator_entries =
      Enum.map(delegator_responses, fn {{pool_address, delegator_address, is_active}, response} ->
        # staking_response = pool_staking_responses[pool_address]

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

  def transform_requests(minig_address) do
    [
      staking_address: {:validator_set, "stakingByMiningAddress", [minig_address]}
    ]
  end

  defp pool_staking_requests(staking_address, block_number) do
    [
      snapshotted_staked_amount: {:staking, "stakeAmountTotal", [staking_address], block_number - 1},
      snapshotted_self_staked_amount: {:staking, "stakeAmount", [staking_address, staking_address], block_number - 1},
      staked_amount: {:staking, "stakeAmountTotal", [staking_address]},
      self_staked_amount: {:staking, "stakeAmount", [staking_address, staking_address]},
      mining_address_hash: {:validator_set, "miningByStakingAddress", [staking_address]},
      active_delegators: {:staking, "poolDelegators", [staking_address]},
      inactive_delegators: {:staking, "poolDelegatorsInactive", [staking_address]}
    ]
  end

  defp delegator_requests(pool_address, delegator_address, block_number) do
    [
      stake_amount: {:staking, "stakeAmount", [pool_address, delegator_address]},
      snapshotted_staked_amount: {:staking, "stakeAmount", [pool_address, delegator_address], block_number - 1},
      ordered_withdraw: {:staking, "orderedWithdrawAmount", [pool_address, delegator_address]},
      max_withdraw_allowed: {:staking, "maxWithdrawAllowed", [pool_address, delegator_address]},
      max_ordered_withdraw_allowed: {:staking, "maxWithdrawOrderAllowed", [pool_address, delegator_address]},
      ordered_withdraw_epoch: {:staking, "orderWithdrawEpoch", [pool_address, delegator_address]}
    ]
  end

  defp abi(file_name) do
    :explorer
    |> Application.app_dir("priv/contracts_abi/posdao/#{file_name}.json")
    |> File.read!()
    |> Jason.decode!()
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
