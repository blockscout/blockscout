defmodule Explorer.Celo.AccountReader do
  @moduledoc """
  Reads information about Celo accounts using Smart Contract functions from the blockchain.
  """

  require Logger
  alias Explorer.Celo.AbiHandler
  alias Explorer.SmartContract.Reader

  def account_data(%{address: account_address}) do
    data = fetch_account_data(account_address)

    with {:ok, [name]} <- data["getName"],
         {:ok, [url]} <- data["getMetadataURL"],
         {:ok, [is_validator]} <- data["isValidator"],
         {:ok, [is_validator_group]} <- data["isValidatorGroup"],
         account_type = determine_account_type(is_validator, is_validator_group),
         {:ok, [gold]} <- data["getAccountTotalLockedGold"],
         {:ok, [nonvoting_gold]} <- data["getAccountNonvotingLockedGold"] do
      {:ok,
       %{
         address: account_address,
         name: name,
         url: url,
         rewards: 0,
         locked_gold: gold,
         nonvoting_locked_gold: nonvoting_gold,
         account_type: account_type
       }}
    else
      _ ->
        :error
    end
  end

  def validator_data(%{address: address}) do
    data = fetch_validator_data(address)

    case data["getValidator"] do
      {:ok, [_, affiliation, score]} <- data["getValidator"] ->
        {:ok,
         %{
           address: address,
           group_address_hash: affiliation,
           score: score
         }}

      _ ->
        :error
    end
  end

  def validator_group_data(%{address: address}) do
    data = fetch_validator_group_data(address)

    case data["getValidatorGroup"] do
      {:ok, [_members, commission, _size_history]} ->
        {:ok,
         %{
           address: address,
           commission: commission
         }}

      _ ->
        :error
    end
  end

  # how to delete them from the table?
  def withdrawal_data(%{address: address}) do
    data = fetch_withdrawal_data(address)

    case data["getPendingWithdrawals"] do
      {:ok, [values, timestamps]} ->
        {:ok,
         %{
           address: address,
           withdrawals:
             Enum.map(Enum.zip(values, timestamps), fn {v, t} -> %{address: address, amount: v, timestamp: t} end)
         }}

      _ ->
        :error
    end
  end

  def validator_history(%{block_number: _block_number}) do
    data = fetch_validators()

    case data["currentValidators"] do
      {:ok, [validators]} ->
        {:ok,
         %{
           validators: validators
         }}
    else
      _ -> :error
    end
  end

  defp determine_account_type(is_validator, is_validator_group) do
    if is_validator do
      "validator"
    else
      if is_validator_group do
        "group"
      else
        "normal"
      end
    end
  end

  defp fetch_account_data(account_address) do
    call_methods([
      {:lockedgold, "getAccountTotalLockedGold", [account_address]},
      {:lockedgold, "getAccountNonvotingLockedGold", [account_address]},
      {:validators, "isValidator", [account_address]},
      {:validators, "isValidatorGroup", [account_address]},
      {:accounts, "getName", [account_address]},
      {:accounts, "getMetadataURL", [account_address]}
    ])
  end

  defp fetch_validator_data(address) do
    data =
      call_methods([
        {:validators, "getValidator", [address]}
      ])

    data
  end

  defp fetch_validators(_bn) do
    data =
      call_methods([
        {:validators, "currentValidators", []}
      ])

    data
  end

  defp fetch_withdrawal_data(address) do
    call_methods([{:locked_gold, "getPendingWithdrawals", [address]}])
  end

  defp fetch_validator_group_data(address) do
    call_methods([
      {:validators, "getValidatorGroup", [address]}
    ])
  end

  defp call_methods(methods) do
    contract_abi = AbiHandler.get_abi()

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
  defp contract(:accounts), do: config(:accounts_contract_address)

  defp config(key) do
    Application.get_env(:explorer, __MODULE__, [])[key]
  end
end
