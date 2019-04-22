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
         {:ok, [is_active]} <- call_staking_method("isPoolActive", [staking_address]),
         {:ok, [delegator_addresses]} <- call_staking_method("poolDelegators", [staking_address]),
         delegators_count = Enum.count(delegator_addresses),
         {:ok, [staked_amount]} <- call_staking_method("stakeAmountTotalMinusOrderedWithdraw", [staking_address]),
         {:ok, [is_validator]} <- call_validators_method("isValidator", [mining_address]),
         {:ok, [was_validator_count]} <- call_validators_method("validatorCounter", [mining_address]),
         {:ok, [is_banned]} <- call_validators_method("isValidatorBanned", [mining_address]),
         {:ok, [banned_unitil]} <- call_validators_method("bannedUntil", [mining_address]),
         {:ok, [was_banned_count]} <- call_validators_method("banCounter", [mining_address]) do
      {
        :ok,
        %{
          staking_address: staking_address,
          mining_address: mining_address,
          is_active: is_active,
          delegators_count: delegators_count,
          staked_amount: staked_amount,
          is_validator: is_validator,
          was_validator_count: was_validator_count,
          is_banned: is_banned,
          banned_unitil: banned_unitil,
          was_banned_count: was_banned_count
        }
      }
    else
      _ ->
        :error
    end
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

  defp config(key) do
    Application.get_env(:explorer, __MODULE__, [])[key]
  end

  defp abi(file_name) do
    :explorer
    |> Application.app_dir("priv/contracts_abi/pos/#{file_name}")
    |> File.read!()
    |> Jason.decode!()
  end
end
