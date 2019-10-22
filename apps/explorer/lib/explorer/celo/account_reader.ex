defmodule Explorer.Celo.AccountReader do
  @moduledoc """
  Reads information about Celo accounts using Smart Contract functions from the blockchain.
  """
  alias Explorer.SmartContract.Reader

  require Logger

  def account_data(%{address: account_address}) do
    with data = fetch_account_data(account_address),
         {:ok, [is_validator]} <- data["isValidator"],
         {:ok, [is_validator_group]} <- data["isValidatorGroup"],
         account_type = determine_account_type(is_validator, is_validator_group),
         {:ok, [gold]} <- data["getAccountTotalLockedGold"],
         {:ok, [nonvoting_gold]} <- data["getAccountNonvotingLockedGold"] do
        {:ok,
        %{
          address: account_address,
          rewards: 0,
          locked_gold: gold,
          locked_nonvoting_gold: nonvoting_gold,
          account_type: account_type,
        }
      }
    else
      _ ->
        :error
    end
  end

  def validator_data(%{address: _address}) do
  end

  def validator_group_data(%{address: _address}) do
  end

  def withdrawal_data(%{address: _address}) do
  end

  def validator_history(%{block_number: _block_number}) do
  end

  defp determine_account_type(is_validator, is_validator_group) do
    if is_validator do "validator"
    else
      if is_validator_group do "group"
      else "normal"
      end
    end
  end

  defp fetch_account_data(account_address) do
    data = call_methods([
      {:lockedgold, "getAccountTotalLockedGold", [account_address]},
      {:lockedgold, "getAccountNonvotingLockedGold", [account_address]},
      {:validators, "isValidator", [account_address]},
      {:validators, "isValidatorGroup", [account_address]},
    ])
    IO.inspect(data)
    data
  end

  defp call_methods(methods) do
    contract_abi = abi("lockedgold.json") ++ abi("validators.json") ++ abi("election.json")
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

  defp contract(:lockedgold), do: config(:lockedgold_contract_address)
  defp contract(:validators), do: config(:validators_contract_address)
  defp contract(:election), do: config(:election_contract_address)

  defp config(key) do
    data = Application.get_env(:explorer, __MODULE__, [])[key]
    data
  end

  # sobelow_skip ["Traversal"]
  defp abi(file_name) do
    :explorer
    |> Application.app_dir("priv/contracts_abi/celo/#{file_name}")
    |> File.read!()
    |> Jason.decode!()
  end

end

