defmodule Explorer.Staking.ContractReader do
  @moduledoc """
  Routines for batched fetching of information from POSDAO contracts.
  """

  alias Explorer.SmartContract.Reader

  def global_requests(block_number) do
    [
      # 673a2a1f = keccak256(getPools())
      active_pools: {:staking, "673a2a1f", [], block_number},
      # 8c2243ae = keccak256(stakingEpochEndBlock())
      epoch_end_block: {:staking, "8c2243ae", [], block_number},
      # 794c0c68 = keccak256(stakingEpoch())
      epoch_number: {:staking, "794c0c68", [], block_number},
      # 7069e746 = keccak256(stakingEpochStartBlock())
      epoch_start_block: {:staking, "7069e746", [], block_number},
      # df6f55f5 = keccak256(getPoolsInactive())
      inactive_pools: {:staking, "df6f55f5", [], block_number},
      # f0786096 = keccak256(MAX_CANDIDATES())
      max_candidates: {:staking, "f0786096", [], block_number},
      # 714897df = keccak256(MAX_VALIDATORS())
      max_validators: {:validator_set, "714897df", [], block_number},
      # 5fef7643 = keccak256(candidateMinStake())
      min_candidate_stake: {:staking, "5fef7643", [], block_number},
      # da7a9b6a = keccak256(delegatorMinStake())
      min_delegator_stake: {:staking, "da7a9b6a", [], block_number},
      # 957950a7 = keccak256(getPoolsLikelihood())
      pools_likelihood: {:staking, "957950a7", [], block_number},
      # a5d54f65 = keccak256(getPoolsToBeElected())
      pools_to_be_elected: {:staking, "a5d54f65", [], block_number},
      # f4942501 = keccak256(areStakeAndWithdrawAllowed())
      staking_allowed: {:staking, "f4942501", [], block_number},
      # 74bdb372 = keccak256(lastChangeBlock())
      staking_last_change_block: {:staking, "74bdb372", [], block_number},
      # 2d21d217 = keccak256(erc677TokenContract())
      token_contract_address: {:staking, "2d21d217", [], block_number},
      # 704189ca = keccak256(unremovableValidator())
      unremovable_validator: {:validator_set, "704189ca", [], block_number},
      # b7ab4db5 = keccak256(getValidators())
      validators: {:validator_set, "b7ab4db5", [], block_number},
      # b927ef43 = keccak256(validatorSetApplyBlock())
      validator_set_apply_block: {:validator_set, "b927ef43", [], block_number},
      # 74bdb372 = keccak256(lastChangeBlock())
      validator_set_last_change_block: {:validator_set, "74bdb372", [], block_number}
    ]
  end

  def active_delegators_request(pool_id, block_number) do
    [
      # 561c4c81 = keccak256(poolDelegators(uint256))
      active_delegators: {:staking, "561c4c81", [pool_id], block_number}
    ]
  end

  # makes a raw `eth_call` for the `currentPoolRewards` function of the BlockReward contract:
  # function currentPoolRewards(
  #     uint256 _rewardToDistribute,
  #     uint256[] memory _blocksCreatedShareNum,
  #     uint256 _blocksCreatedShareDenom,
  #     uint256 _stakingEpoch
  # ) public view returns(uint256[] memory poolRewards);
  def call_current_pool_rewards(block_reward_address, reward_to_distribute, staking_epoch, block_number) do
    json_rpc_named_arguments = Application.get_env(:explorer, :json_rpc_named_arguments)

    reward_to_distribute =
      reward_to_distribute
      |> Integer.to_string(16)
      |> String.pad_leading(64, ["0"])

    staking_epoch =
      staking_epoch
      |> Integer.to_string(16)
      |> String.pad_leading(64, ["0"])

    function_signature = "0x212329f3"

    data =
      function_signature <>
        reward_to_distribute <>
        "00000000000000000000000000000000000000000000000000000000000000800000000000000000000000000000000000000000000000000000000000000000" <>
        staking_epoch <> "0000000000000000000000000000000000000000000000000000000000000000"

    request = %{
      id: 0,
      method: "eth_call",
      params: [
        %{
          to: block_reward_address,
          data: data
        },
        "0x" <> Integer.to_string(block_number, 16)
      ]
    }

    result =
      request
      |> EthereumJSONRPC.request()
      |> EthereumJSONRPC.json_rpc(json_rpc_named_arguments)

    case result do
      {:ok, response} ->
        response =
          response
          |> String.replace_leading("0x", "")
          |> Base.decode16!(case: :lower)

        decoded = ABI.decode("res(uint256[])", response)
        Enum.at(decoded, 0)

      {:error, _} ->
        []
    end
  end

  # makes a raw `eth_call` for the `currentTokenRewardToDistribute` function of the BlockReward contract:
  # function currentTokenRewardToDistribute(
  #     address _stakingContract,
  #     uint256 _stakingEpoch,
  #     uint256 _totalRewardShareNum,
  #     uint256 _totalRewardShareDenom,
  #     uint256[] memory _validators
  # ) public view returns(uint256 rewardToDistribute, uint256 totalReward);
  def call_current_token_reward_to_distribute(
        block_reward_address,
        staking_contract_address,
        staking_epoch,
        block_number
      ) do
    json_rpc_named_arguments = Application.get_env(:explorer, :json_rpc_named_arguments)

    staking_contract_address = address_pad_to_64(staking_contract_address)

    staking_epoch =
      staking_epoch
      |> Integer.to_string(16)
      |> String.pad_leading(64, ["0"])

    function_signature = "0x43544960"
    mandatory_params = staking_contract_address <> staking_epoch

    optional_params =
      "0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000a00000000000000000000000000000000000000000000000000000000000000000"

    data = function_signature <> mandatory_params <> optional_params

    request = %{
      id: 0,
      method: "eth_call",
      params: [
        %{
          to: block_reward_address,
          data: data
        },
        "0x" <> Integer.to_string(block_number, 16)
      ]
    }

    result =
      request
      |> EthereumJSONRPC.request()
      |> EthereumJSONRPC.json_rpc(json_rpc_named_arguments)

    case result do
      {:ok, response} ->
        response =
          response
          |> String.replace_leading("0x", "")
          |> Base.decode16!(case: :lower)

        decoded = ABI.decode("res(uint256,uint256)", response)
        Enum.at(decoded, 0)

      {:error, _} ->
        0
    end
  end

  # makes a raw `eth_call` for the `getRewardAmount` function of the Staking contract:
  # function getRewardAmount(
  #   uint256[] memory _stakingEpochs,
  #   address _poolStakingAddress,
  #   address _staker
  # ) public view returns(uint256 tokenRewardSum, uint256 nativeRewardSum);
  def call_get_reward_amount(
        staking_contract_address,
        staking_epochs,
        pool_staking_address,
        staker,
        json_rpc_named_arguments
      ) do
    staking_epochs_joint =
      staking_epochs
      |> Enum.map_join(fn epoch ->
        epoch
        |> Integer.to_string(16)
        |> String.pad_leading(64, ["0"])
      end)

    pool_staking_address = address_pad_to_64(pool_staking_address)
    staker = address_pad_to_64(staker)

    staking_epochs_length =
      staking_epochs
      |> Enum.count()
      |> Integer.to_string(16)
      |> String.pad_leading(64, ["0"])

    # `getRewardAmount` function signature
    function_signature = "0xfb367a9b"
    # offset to the `_stakingEpochs` array
    function_signature_with_offset = function_signature <> String.pad_leading("60", 64, ["0"])
    # `_poolStakingAddress` parameter
    function_with_param_1 = function_signature_with_offset <> pool_staking_address
    # `_staker` parameter
    function_with_param1_param2 = function_with_param_1 <> staker
    # the length of `_stakingEpochs` array
    function_with_param_1_length_param2 = function_with_param1_param2 <> staking_epochs_length
    # encoded `_stakingEpochs` array
    data = function_with_param_1_length_param2 <> staking_epochs_joint

    request = %{
      id: 0,
      method: "eth_call",
      params: [
        %{
          to: staking_contract_address,
          data: data
        }
      ]
    }

    result =
      request
      |> EthereumJSONRPC.request()
      |> EthereumJSONRPC.json_rpc(json_rpc_named_arguments)

    case result do
      {:ok, response} ->
        response = String.replace_leading(response, "0x", "")

        if String.length(response) != 64 * 2 do
          {:error, "Invalid getRewardAmount response."}
        else
          {token_reward_sum, native_reward_sum} = String.split_at(response, 64)
          token_reward_sum = String.to_integer(token_reward_sum, 16)
          native_reward_sum = String.to_integer(native_reward_sum, 16)
          {:ok, %{token_reward_sum: token_reward_sum, native_reward_sum: native_reward_sum}}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  # makes a raw `eth_estimateGas` for the `claimReward` function of the Staking contract:
  # function claimReward(
  #   uint256[] memory _stakingEpochs,
  #   address _poolStakingAddress
  # ) public;
  def claim_reward_estimate_gas(
        staking_contract_address,
        staking_epochs,
        pool_staking_address,
        staker,
        json_rpc_named_arguments
      ) do
    staking_epochs_joint =
      staking_epochs
      |> Enum.map_join(fn epoch ->
        epoch
        |> Integer.to_string(16)
        |> String.pad_leading(64, ["0"])
      end)

    pool_staking_address = address_pad_to_64(pool_staking_address)

    staking_epochs_length =
      staking_epochs
      |> Enum.count()
      |> Integer.to_string(16)
      |> String.pad_leading(64, ["0"])

    # `claimReward` function signature
    function_signature = "0x3ea15d62"
    # offset to the `_stakingEpochs` array
    function_signature_with_offset = function_signature <> String.pad_leading("40", 64, ["0"])
    # `_poolStakingAddress` parameter
    function_with_param_1 = function_signature_with_offset <> pool_staking_address
    # the length of `_stakingEpochs` array
    function_with_param_1_length_param2 = function_with_param_1 <> staking_epochs_length
    # encoded `_stakingEpochs` array
    data = function_with_param_1_length_param2 <> staking_epochs_joint

    request = %{
      id: 0,
      method: "eth_estimateGas",
      params: [
        %{
          from: staker,
          to: staking_contract_address,
          # 1 gwei
          gasPrice: "0x3B9ACA00",
          data: data
        }
      ]
    }

    result =
      request
      |> EthereumJSONRPC.request()
      |> EthereumJSONRPC.json_rpc(json_rpc_named_arguments)

    case result do
      {:ok, response} ->
        estimate =
          response
          |> String.replace_leading("0x", "")
          |> String.to_integer(16)

        {:ok, estimate}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # args = [staking_epoch, delegator_staked, validator_staked, total_staked, pool_reward \\ 10_00000]
  def delegator_reward_request(args, block_number) do
    [
      # 5fba554e = keccak256(delegatorShare(uint256,uint256,uint256,uint256,uint256))
      delegator_share: {:block_reward, "5fba554e", args, block_number}
    ]
  end

  def epochs_to_claim_reward_from_request(staking_address, staker) do
    [
      # 4de6c036 = keccak256(epochsToClaimRewardFrom(address,address))
      epochs: {:block_reward, "4de6c036", [staking_address, staker]}
    ]
  end

  def get_delegator_pools_request(delegator, offset, length) do
    [
      # 2ebfaf4e = keccak256(getDelegatorPools(address,uint256,uint256))
      pools: {:staking, "2ebfaf4e", [delegator, offset, length]}
    ]
  end

  def get_delegator_pools_length_request(delegator) do
    [
      # 8ba31a1c = keccak256(getDelegatorPoolsLength(address))
      length: {:staking, "8ba31a1c", [delegator]}
    ]
  end

  def mining_by_id_request(pool_id, block_number) do
    [
      # e2847895 = keccak256(miningAddressById(uint256))
      mining_address: {:validator_set, "e2847895", [pool_id], block_number}
    ]
  end

  def mining_by_staking_request(staking_address) do
    [
      # 00535175 = keccak256(miningByStakingAddress(address))
      mining_address: {:validator_set, "00535175", [staking_address]}
    ]
  end

  def mining_by_staking_request(staking_address, block_number) do
    [
      # 00535175 = keccak256(miningByStakingAddress(address))
      mining_address: {:validator_set, "00535175", [staking_address], block_number}
    ]
  end

  def pool_staking_requests(pool_id, block_number) do
    [
      active_delegators: active_delegators_request(pool_id, block_number)[:active_delegators],
      # 378bf28b = keccak256(poolDescription(uint256))
      description: {:validator_set, "378bf28b", [pool_id], block_number},
      # a1fc2753 = keccak256(poolDelegatorsInactive(uint256))
      inactive_delegators: {:staking, "a1fc2753", [pool_id], block_number},
      # bbbaf8c8 = keccak256(isPoolActive(uint256))
      is_active: {:staking, "bbbaf8c8", [pool_id], block_number},
      mining_address_hash: mining_by_id_request(pool_id, block_number)[:mining_address],
      name: pool_name_request(pool_id, block_number)[:name],
      staking_address_hash: staking_by_id_request(pool_id, block_number)[:staking_address],
      # 3fb1a1e4 = keccak256(stakeAmount(uint256,address))
      self_staked_amount: {:staking, "3fb1a1e4", [pool_id, "0x0000000000000000000000000000000000000000"], block_number},
      # 2a8f6ecd = keccak256(stakeAmountTotal(uint256))
      total_staked_amount: {:staking, "2a8f6ecd", [pool_id], block_number},
      # 3bf47e96 = keccak256(validatorRewardPercent(uint256))
      validator_reward_percent: {:block_reward, "3bf47e96", [pool_id], block_number}
    ]
  end

  def pool_mining_requests(mining_address, block_number) do
    [
      # a881c5fd = keccak256(areDelegatorsBanned(address))
      are_delegators_banned: {:validator_set, "a881c5fd", [mining_address], block_number},
      # c9e9694d = keccak256(banReason(address))
      ban_reason: {:validator_set, "c9e9694d", [mining_address], block_number},
      # 5836d08a = keccak256(bannedUntil(address))
      banned_until: {:validator_set, "5836d08a", [mining_address], block_number},
      # 1a7fa237 = keccak256(bannedDelegatorsUntil(address))
      banned_delegators_until: {:validator_set, "1a7fa237", [mining_address], block_number},
      # a92252ae = keccak256(isValidatorBanned(address))
      is_banned: {:validator_set, "a92252ae", [mining_address], block_number},
      # b41832e4 = keccak256(validatorCounter(address))
      was_validator_count: {:validator_set, "b41832e4", [mining_address], block_number},
      # 1d0cd4c6 = keccak256(banCounter(address))
      was_banned_count: {:validator_set, "1d0cd4c6", [mining_address], block_number}
    ]
  end

  def pool_name_request(pool_id, block_number) do
    [
      # cccf3a02 = keccak256(poolName(uint256))
      name: {:validator_set, "cccf3a02", [pool_id], block_number}
    ]
  end

  def staker_requests(pool_id, pool_staking_address, staker_address, block_number) do
    delegator_or_zero =
      if staker_address == pool_staking_address do
        "0x0000000000000000000000000000000000000000"
      else
        staker_address
      end

    [
      # 950a6513 = keccak256(maxWithdrawOrderAllowed(address,address))
      max_ordered_withdraw_allowed: {:staking, "950a6513", [pool_staking_address, staker_address], block_number},
      # 6bda1577 = keccak256(maxWithdrawAllowed(address,address))
      max_withdraw_allowed: {:staking, "6bda1577", [pool_staking_address, staker_address], block_number},
      # e3f0ff66 = keccak256(orderedWithdrawAmount(uint256,address))
      ordered_withdraw: {:staking, "e3f0ff66", [pool_id, delegator_or_zero], block_number},
      # d2f2a136 = keccak256(orderWithdrawEpoch(uint256,address))
      ordered_withdraw_epoch: {:staking, "d2f2a136", [pool_id, delegator_or_zero], block_number},
      # 3fb1a1e4 = keccak256(stakeAmount(uint256,address))
      stake_amount: {:staking, "3fb1a1e4", [pool_id, delegator_or_zero], block_number}
    ]
  end

  def staking_by_id_request(pool_id) do
    [
      # 16cf66ab = keccak256(stakingAddressById(uint256))
      staking_address: {:validator_set, "16cf66ab", [pool_id]}
    ]
  end

  def staking_by_id_request(pool_id, block_number) do
    [
      # 16cf66ab = keccak256(stakingAddressById(uint256))
      staking_address: {:validator_set, "16cf66ab", [pool_id], block_number}
    ]
  end

  def id_by_mining_request(mining_address, block_number) do
    [
      # 2bbb7b72 = keccak256(idByMiningAddress(address))
      pool_id: {:validator_set, "2bbb7b72", [mining_address], block_number}
    ]
  end

  def id_by_staking_request(staking_address) do
    [
      # a26301f9 = keccak256(idByStakingAddress(address))
      pool_id: {:validator_set, "a26301f9", [staking_address]}
    ]
  end

  def staking_by_mining_request(mining_address, block_number) do
    [
      # 1ee4d0bc = keccak256(stakingByMiningAddress(address))
      staking_address: {:validator_set, "1ee4d0bc", [mining_address], block_number}
    ]
  end

  def validator_min_reward_percent_request(epoch_number, block_number) do
    [
      # cdf7a090 = keccak256(validatorMinRewardPercent(uint256))
      value: {:block_reward, "cdf7a090", [epoch_number], block_number}
    ]
  end

  # args = [staking_epoch, validator_staked, total_staked, pool_reward \\ 10_00000]
  def validator_reward_request(args, block_number) do
    [
      # 8737929a = keccak256(validatorShare(uint256,uint256,uint256,uint256))
      validator_share: {:block_reward, "8737929a", args, block_number}
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

  def get_contract_events(contract_address, from_block, to_block, event_hash) do
    json_rpc_named_arguments = Application.get_env(:explorer, :json_rpc_named_arguments)

    result =
      %{
        id: 0,
        method: "eth_getLogs",
        params: [
          %{
            fromBlock: "0x" <> Integer.to_string(from_block, 16),
            toBlock: "0x" <> Integer.to_string(to_block, 16),
            address: contract_address,
            topics: [event_hash]
          }
        ]
      }
      |> EthereumJSONRPC.request()
      |> EthereumJSONRPC.json_rpc(json_rpc_named_arguments)

    case result do
      {:ok, events} ->
        events

      {:error, _reason} ->
        []
    end
  end

  defp address_pad_to_64(address) do
    address
    |> String.replace_leading("0x", "")
    |> String.pad_leading(64, ["0"])
  end

  defp generate_requests(functions, contracts) do
    Enum.map(functions, fn
      {_, {contract, method_id, args}} ->
        %{
          contract_address: contracts[contract],
          method_id: method_id,
          args: args
        }

      {_, {contract, method_id, args, block_number}} ->
        %{
          contract_address: contracts[contract],
          method_id: method_id,
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
