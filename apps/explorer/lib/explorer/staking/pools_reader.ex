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
    {:ok, [active_pools]} = call_staking_method("getPools", [])
    active_pools
  end

  @spec get_inactive_pools() :: [String.t()]
  def get_inactive_pools do
    {:ok, [inactive_pools]} = call_staking_method("getPoolsInactive", [])
    inactive_pools
  end

  @spec pool_data(String.t()) :: {:ok, map()} | :error
  def pool_data(staking_address) do
    with {:ok, [mining_address]} <- call_validators_method("miningByStakingAddress", [staking_address]),
         data = fetch_pool_data(staking_address, mining_address),
         {:ok, [is_active]} <- data["isPoolActive"],
         {:ok, [delegator_addresses]} <- data["poolDelegators"],
         delegators_count = Enum.count(delegator_addresses),
         delegators = delegators_data(delegator_addresses, staking_address),
         {:ok, [staked_amount]} <- data["stakeAmountTotalMinusOrderedWithdraw"],
         {:ok, [self_staked_amount]} <- data["stakeAmountMinusOrderedWithdraw"],
         {:ok, [is_validator]} <- data["isValidator"],
         {:ok, [was_validator_count]} <- data["validatorCounter"],
         {:ok, [is_banned]} <- data["isValidatorBanned"],
         {:ok, [banned_until]} <- data["bannedUntil"],
         {:ok, [was_banned_count]} <- data["banCounter"] do
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
      data =
        call_methods([
          {:staking, "stakeAmount", [pool_address, address]},
          {:staking, "orderedWithdrawAmount", [pool_address, address]},
          {:staking, "maxWithdrawAllowed", [pool_address, address]},
          {:staking, "maxWithdrawOrderAllowed", [pool_address, address]},
          {:staking, "orderWithdrawEpoch", [pool_address, address]}
        ])

      {:ok, [stake_amount]} = data["stakeAmount"]
      {:ok, [ordered_withdraw]} = data["orderedWithdrawAmount"]
      {:ok, [max_withdraw_allowed]} = data["maxWithdrawAllowed"]
      {:ok, [max_ordered_withdraw_allowed]} = data["maxWithdrawOrderAllowed"]
      {:ok, [ordered_withdraw_epoch]} = data["orderWithdrawEpoch"]

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
    call_methods([
      {:staking, "isPoolActive", [staking_address]},
      {:staking, "poolDelegators", [staking_address]},
      {:staking, "stakeAmountTotalMinusOrderedWithdraw", [staking_address]},
      {:staking, "stakeAmountMinusOrderedWithdraw", [staking_address, staking_address]},
      {:validators, "isValidator", [mining_address]},
      {:validators, "validatorCounter", [mining_address]},
      {:validators, "isValidatorBanned", [mining_address]},
      {:validators, "bannedUntil", [mining_address]},
      {:validators, "banCounter", [mining_address]}
    ])
  end

  defp call_methods(methods) do
    contract_abi = abi("staking.json") ++ abi("validators.json")

    methods
    |> Enum.map(&format_request/1)
    |> Reader.query_contracts(contract_abi)
    |> Enum.zip(methods)
    |> Enum.into(%{}, fn {response, {_, function_name, _}} ->
      {function_name, response}
    end)
  end

  defp format_request({contract_name, function_name, params}) do
    %{
      contract_address: contract(contract_name),
      function_name: function_name,
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
