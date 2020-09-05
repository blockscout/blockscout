defmodule Explorer.Staking.PoolsReader do
  @moduledoc """
  Reads staking pools using Smart Contract functions from the blockchain.
  """
  alias Explorer.SmartContract.Reader

  @spec get_pools() :: [String.t()]
  def get_pools do
    get_active_pools() ++ get_inactive_pools()
  end

  @spec get_active_pools() :: [String.t()]
  def get_active_pools do
    # 673a2a1f = keccak256(getPools())
    {:ok, [active_pools]} = call_staking_method("673a2a1f", [])
    active_pools
  end

  @spec get_inactive_pools() :: [String.t()]
  def get_inactive_pools do
    # df6f55f5 = keccak256(getPoolsInactive())
    {:ok, [inactive_pools]} = call_staking_method("df6f55f5", [])
    inactive_pools
  end

  @spec pool_data(String.t()) :: {:ok, map()} | :error
  def pool_data(staking_address) do
    # 00535175 = keccak256(miningByStakingAddress(address))
    with {:ok, [mining_address]} <- call_validators_method("00535175", [staking_address]),
         data = fetch_pool_data(staking_address, mining_address),
         {:ok, [is_active]} <- data["a711e6a1"],
         {:ok, [delegator_addresses]} <- data["9ea8082b"],
         delegators_count = Enum.count(delegator_addresses),
         delegators = delegators_data(delegator_addresses, staking_address),
         {:ok, [staked_amount]} <- data["234fbf2b"],
         {:ok, [self_staked_amount]} <- data["58daab6a"],
         {:ok, [is_validator]} <- data["facd743b"],
         {:ok, [was_validator_count]} <- data["b41832e4"],
         {:ok, [is_banned]} <- data["a92252ae"],
         {:ok, [banned_until]} <- data["5836d08a"],
         {:ok, [was_banned_count]} <- data["1d0cd4c6"] do
      {
        :ok,
        %{
          staking_address_hash: staking_address,
          mining_address_hash: mining_address,
          is_active: is_active,
          delegators_count: delegators_count,
          staked_amount: staked_amount,
          self_staked_amount: self_staked_amount,
          is_validator: is_validator,
          was_validator_count: was_validator_count,
          is_banned: is_banned,
          banned_until: banned_until,
          was_banned_count: was_banned_count,
          delegators: delegators
        }
      }
    else
      _ ->
        :error
    end
  end

  defp delegators_data(delegators, pool_address) do
    Enum.map(delegators, fn address ->
      # a697ecff = keccak256(stakeAmount(address,address))
      # e9ab0300 = keccak256(orderedWithdrawAmount(address,address))
      # 6bda1577 = keccak256(maxWithdrawAllowed(address,address))
      # 950a6513 = keccak256(maxWithdrawOrderAllowed(address,address))
      # a4205967 = keccak256(orderWithdrawEpoch(address,address))
      data =
        call_methods([
          {:staking, "a697ecff", [pool_address, address]},
          {:staking, "e9ab0300", [pool_address, address]},
          {:staking, "6bda1577", [pool_address, address]},
          {:staking, "950a6513", [pool_address, address]},
          {:staking, "a4205967", [pool_address, address]}
        ])

      {:ok, [stake_amount]} = data["a697ecff"]
      {:ok, [ordered_withdraw]} = data["e9ab0300"]
      {:ok, [max_withdraw_allowed]} = data["6bda1577"]
      {:ok, [max_ordered_withdraw_allowed]} = data["950a6513"]
      {:ok, [ordered_withdraw_epoch]} = data["a4205967"]

      %{
        delegator_address_hash: address,
        pool_address_hash: pool_address,
        stake_amount: stake_amount,
        ordered_withdraw: ordered_withdraw,
        max_withdraw_allowed: max_withdraw_allowed,
        max_ordered_withdraw_allowed: max_ordered_withdraw_allowed,
        ordered_withdraw_epoch: ordered_withdraw_epoch
      }
    end)
  end

  defp call_staking_method(method, params) do
    %{^method => resp} =
      Reader.query_contract(config(:staking_contract_address), abi("staking.json"), %{
        method => params
      })

    resp
  end

  defp call_validators_method(method, params) do
    %{^method => resp} =
      Reader.query_contract(config(:validators_contract_address), abi("validators.json"), %{
        method => params
      })

    resp
  end

  defp fetch_pool_data(staking_address, mining_address) do
    # a711e6a1 = keccak256(isPoolActive(address))
    # 9ea8082b = keccak256(poolDelegators(address))
    # 234fbf2b = keccak256(stakeAmountTotalMinusOrderedWithdraw(address))
    # 58daab6a = keccak256(stakeAmountMinusOrderedWithdraw(address,address))
    # facd743b = keccak256(isValidator(address))
    # b41832e4 = keccak256(validatorCounter(address))
    # a92252ae = keccak256(isValidatorBanned(address))
    # 5836d08a = keccak256(bannedUntil(address))
    # 1d0cd4c6 = keccak256(banCounter(address))
    call_methods([
      {:staking, "a711e6a1", [staking_address]},
      {:staking, "9ea8082b", [staking_address]},
      {:staking, "234fbf2b", [staking_address]},
      {:staking, "58daab6a", [staking_address, staking_address]},
      {:validators, "facd743b", [mining_address]},
      {:validators, "b41832e4", [mining_address]},
      {:validators, "a92252ae", [mining_address]},
      {:validators, "5836d08a", [mining_address]},
      {:validators, "1d0cd4c6", [mining_address]}
    ])
  end

  defp call_methods(methods) do
    contract_abi = abi("staking.json") ++ abi("validators.json")

    methods
    |> Enum.map(&format_request/1)
    |> Reader.query_contracts(contract_abi)
    |> Enum.zip(methods)
    |> Enum.into(%{}, fn {response, {_, method_id, _}} ->
      {method_id, response}
    end)
  end

  defp format_request({contract_name, method_id, params}) do
    %{
      contract_address: contract(contract_name),
      method_id: method_id,
      args: params
    }
  end

  defp contract(:staking), do: config(:staking_contract_address)
  defp contract(:validators), do: config(:validators_contract_address)

  defp config(key) do
    Application.get_env(:explorer, __MODULE__, [])[key]
  end

  # sobelow_skip ["Traversal"]
  defp abi(file_name) do
    :explorer
    |> Application.app_dir("priv/contracts_abi/pos/#{file_name}")
    |> File.read!()
    |> Jason.decode!()
  end
end
